extends Node2D

@onready var arm_sprite = $ArmSprite
@onready var pickup_area = $PickupArea
@onready var grab_point = $ArmSprite/GrabPoint
@onready var drop_area = $DropArea

# State variables
var is_placed := false
var current_direction := 0 # Prevents the BuildManager crash!
var held_item: Node2D = null
@export var swing_time: float = 0.5 # Time in seconds it takes to swing
var is_busy := false # Tracks if the arm is currently in motion
var is_waiting_to_drop := false # Tracks if the arm is hovering, waiting for a gap

# --- NEW: Identify what item this building costs ---
@export var building_item_id: String = "inserter"

func check_for_existing_items() -> void:
	# Wait one physics frame for the collision boundaries to actually exist in the world
	await get_tree().physics_frame
	
	# Manually poll the area for items
	for area in pickup_area.get_overlapping_areas():
		if area.is_in_group("items") and not is_busy:
			is_busy = true
			call_deferred("grab_item", area)
			break # Stop checking after grabbing the first one
			
func _ready() -> void:
	if not is_placed:
		BuildManager.current_preview = self
		modulate.a = 0.5
	else:
		# If placed via the editor, start listening for items
		pickup_area.area_entered.connect(_on_pickup_area_entered)
		
		# --- NEW FIX: Check for stranded items upon map load ---
		check_for_existing_items()

# --- NEW: 1x1 Building footprint ---
func get_occupied_cells(center_cell: Vector2i) -> Array[Vector2i]:
	return [center_cell]

func _process(_delta: float) -> void:
	if is_placed:
		return
		
	var mouse_pos = get_global_mouse_position()
	var current_grid_cell = GridManager.world_to_grid(mouse_pos)
	global_position = GridManager.grid_to_world(current_grid_cell)

	# --- NEW: Universal Red/White Overlay Check ---
	var cells_to_check = get_occupied_cells(current_grid_cell)
	
	# GridManager checks if the physical space is clear AND if inventory has stock
	if GridManager.is_placement_blocked(cells_to_check, building_item_id):
		modulate = Color(1.0, 0.4, 0.4, 0.8) # Red if blocked
	else:
		modulate = Color(1.0, 1.0, 1.0, 0.5) # White if clear

func _physics_process(_delta: float) -> void:
	# --- FIX: Keep the held item completely upright relative to the screen ---
	if held_item:
		held_item.global_rotation = 0.0

	# Run the drop checking logic every physics frame if we are waiting for a gap
	if is_waiting_to_drop:
		try_drop_item()

func _unhandled_input(event: InputEvent) -> void:
	if not is_placed:
		# Rotate preview
		if event is InputEventKey and event.keycode == KEY_R and event.pressed:
			rotation_degrees += 90
			current_direction = (current_direction + 1) % 4
			
		# Place building
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var current_grid_cell = GridManager.world_to_grid(get_global_mouse_position())
			
			# --- UPDATED: Pass the ARRAY of cells to the GridManager! ---
			var cells_to_claim = get_occupied_cells(current_grid_cell)
			
			# GridManager now handles checking the inventory AND deducting the item!
			var success = GridManager.place_item(cells_to_claim, self)
			
			if success:
				is_placed = true
				modulate = Color(1.0, 1.0, 1.0, 1.0) # Reset color fully back to normal
				pickup_area.area_entered.connect(_on_pickup_area_entered)
				
				# --- NEW FIX: Check for stranded items immediately upon placement ---
				check_for_existing_items()
				
				var next_arm = load(scene_file_path).instantiate()
				next_arm.current_direction = current_direction
				next_arm.rotation_degrees = rotation_degrees
				get_parent().add_child(next_arm)
	else:
		# If the building IS placed, listen for F and B to manually test the arm
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_F and not is_busy:
				swing_arm_forward()
			elif event.keycode == KEY_B:
				swing_arm_back()

# --- AUTOMATED MOVEMENT LOGIC ---

func _on_pickup_area_entered(area: Area2D) -> void:
	if area.is_in_group("items") and not is_busy:
		# Lock it INSTANTLY so it can't queue multiple grabs from competing arms
		is_busy = true
		# Use call_deferred to safely trigger the grab AFTER physics math is done
		call_deferred("grab_item", area)

func grab_item(item: Node2D) -> void:
	# Abort if another inserter stole it while we were waiting for the frame to end!
	if not item.is_in_group("items"):
		is_busy = false
		return
		
	held_item = item
	
	item.remove_from_group("items")
	item.set_physics_process(false) 
	
	# --- NEW: Hide the item from the physics engine while carried ---
	item.set_deferred("monitorable", false)
	item.set_deferred("monitoring", false)
	
	# Use Godot 4's reparent function! 
	# Passing 'false' snaps it directly to the claw's local space.
	item.reparent(grab_point, false)
	item.position = Vector2.ZERO 
	
	swing_arm_forward()
	
func swing_arm_forward() -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(arm_sprite, "rotation_degrees", 180.0, swing_time)
	
	tween.tween_callback(drop_item)

func drop_item() -> void:
	# Instead of dropping instantly, tell the inserter to start scanning for a gap!
	if held_item:
		is_waiting_to_drop = true

func try_drop_item() -> void:
	if not held_item:
		is_waiting_to_drop = false
		return
		
	# --- 1. Calculate the FAR lane precisely ---
	# Find the direction from the base to the drop area, and push 16 pixels further
	var reach_dir = (drop_area.global_position - global_position).normalized()
	var far_lane_pos = drop_area.global_position + (reach_dir * 16.0)
	
	# --- 2. Check if that exact spot is clear ---
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = RectangleShape2D.new()
	
	# Use a 26x26 box (slightly larger than the bumper) to guarantee a clean gap
	shape.size = Vector2(26, 26) 
	query.shape = shape
	query.transform = Transform2D(0, far_lane_pos)
	query.collide_with_areas = true
	
	var hits = space_state.intersect_shape(query)
	var blocked = false
	
	for hit in hits:
		if hit.collider.is_in_group("items") and hit.collider != held_item:
			blocked = true
			break
			
	# --- 3. If clear, release the item! ---
	if not blocked:
		is_waiting_to_drop = false
		
		var main_level = get_tree().current_scene
		held_item.reparent(main_level)
		
		# Spawn exactly on the far lane!
		held_item.global_position = far_lane_pos
		
		held_item.add_to_group("items")
		held_item.set_physics_process(true)
		
		# --- NEW: Reveal the item so it triggers area_entered again! ---
		held_item.set_deferred("monitorable", true)
		held_item.set_deferred("monitoring", true)
		
		held_item = null
		swing_arm_back()

func swing_arm_back() -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(arm_sprite, "rotation_degrees", 0.0, swing_time)
	
	# When the arm is completely finished swinging back, reset it
	tween.tween_callback(reset_arm)

func reset_arm() -> void:
	is_busy = false # Unlock the arm
	
	# Check if another item rolled into the area while we were busy!
	for area in pickup_area.get_overlapping_areas():
		if area.is_in_group("items"):
			# Lock immediately again and grab the item that waited!
			is_busy = true
			call_deferred("grab_item", area)
			break # Stop checking after grabbing one
