extends Node2D

@onready var arm_sprite = $ArmSprite
@onready var pickup_area = $PickupArea
@onready var grab_point = $ArmSprite/GrabPoint
@onready var drop_area = $DropArea

# State variables
var is_placed := false
var current_direction := 0 # Prevents BuildManager crash
var held_item: Node2D = null
@export var swing_time: float = 0.5 # Time in seconds it takes to swing
var is_busy := false # Tracks if the arm is currently in motion
var is_waiting_to_drop := false # Tracks if the arm is hovering, waiting for a gap

# Identify building cost item
@export var building_item_id: String = "inserter"

func _ready() -> void:
	if not is_placed:
		BuildManager.current_preview = self
		modulate.a = 0.5
	else:
		pickup_area.area_entered.connect(_on_pickup_area_entered)
		check_for_existing_items()

func check_for_existing_items() -> void:
	await get_tree().physics_frame
	for area in pickup_area.get_overlapping_areas():
		if area.is_in_group("items") and not is_busy:
			is_busy = true
			call_deferred("grab_item", area)
			break

func get_occupied_cells(center_cell: Vector2i) -> Array[Vector2i]:
	return [center_cell]

func _process(_delta: float) -> void:
	if is_placed:
		return
		
	var current_grid_cell = GridManager.world_to_grid(get_global_mouse_position())
	global_position = GridManager.grid_to_world(current_grid_cell)

	var cells_to_check = get_occupied_cells(current_grid_cell)
	if GridManager.is_placement_blocked(cells_to_check) or InventoryManager.get_item_count(building_item_id) <= 0:
		modulate = Color(1.0, 0.4, 0.4, 0.8) # Red if blocked or out of stock
	else:
		modulate = Color(1.0, 1.0, 1.0, 0.5) # Semi-transparent preview

func _physics_process(_delta: float) -> void:
	if held_item:
		held_item.global_rotation = 0.0

	if is_waiting_to_drop:
		try_drop_item()

func _unhandled_input(event: InputEvent) -> void:
	if is_placed:
		return
		
	if event is InputEventKey and event.keycode == KEY_R and event.pressed:
		rotate_inserter()
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		attempt_placement()
		
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		attempt_placement()

func rotate_inserter() -> void:
	current_direction = (current_direction + 1) % 4
	rotation_degrees += 90

func attempt_placement() -> void:
	if InventoryManager.get_item_count(building_item_id) <= 0:
		return
		
	var current_grid_cell = GridManager.world_to_grid(get_global_mouse_position())
	var cells_to_claim = get_occupied_cells(current_grid_cell)
	
	if GridManager.is_placement_blocked(cells_to_claim):
		return
		
	var success = GridManager.place_item(cells_to_claim, self)
	if success:
		global_position = GridManager.grid_to_world(current_grid_cell)
		is_placed = true
		modulate = Color(1.0, 1.0, 1.0, 1.0)
		
		# Activate inserter functions
		if pickup_area and not pickup_area.area_entered.is_connected(_on_pickup_area_entered):
			pickup_area.area_entered.connect(_on_pickup_area_entered)
		check_for_existing_items()
		
		# Spawn next preview
		var next_building = BuildManager.selected_scene.instantiate()
		get_parent().add_child(next_building)
		next_building.rotation_degrees = rotation_degrees
		if "current_direction" in next_building:
			next_building.current_direction = current_direction

func _on_pickup_area_entered(area: Area2D) -> void:
	if not is_placed or is_busy:
		return
		
	if area.is_in_group("items"):
		is_busy = true
		call_deferred("grab_item", area)

func grab_item(item: Node2D) -> void:
	held_item = item
	held_item.reparent(grab_point)
	held_item.position = Vector2.ZERO
	held_item.set_physics_process(false)
	
	held_item.set_deferred("monitorable", false)
	held_item.set_deferred("monitoring", false)
	
	swing_arm_to_drop()

func swing_arm_to_drop() -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(arm_sprite, "rotation_degrees", 180.0, swing_time)
	tween.finished.connect(try_drop_item)

func try_drop_item() -> void:
	if not held_item:
		return
		
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = RectangleShape2D.new()
	
	var drop_pos = drop_area.global_position
	shape.size = Vector2(26, 26)
	query.shape = shape
	query.transform = Transform2D(0, drop_pos)
	query.collide_with_areas = true
	
	var hits = space_state.intersect_shape(query)
	var blocked = false
	
	for hit in hits:
		if hit.collider.is_in_group("items") and hit.collider != held_item:
			blocked = true
			break
			
	if not blocked:
		is_waiting_to_drop = false
		var main_level = get_tree().current_scene
		held_item.reparent(main_level)
		held_item.global_position = drop_pos
		held_item.add_to_group("items")
		held_item.set_physics_process(true)
		held_item.set_deferred("monitorable", true)
		held_item.set_deferred("monitoring", true)
		held_item = null
		swing_arm_back()
	else:
		is_waiting_to_drop = true

func swing_arm_back() -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(arm_sprite, "rotation_degrees", 0.0, swing_time)
	
	await tween.finished
	is_busy = false
	check_for_existing_items()
