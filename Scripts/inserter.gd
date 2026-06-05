extends Node2D

@onready var arm_sprite = $ArmSprite
@onready var pickup_area = $PickupArea
@onready var grab_point = $ArmSprite/GrabPoint

# State variables
var is_placed := false
var current_direction := 0 # Prevents the BuildManager crash!
var held_item: Node2D = null
@export var swing_time: float = 0.5 # Time in seconds it takes to swing
var is_busy := false # Tracks if the arm is currently in motion

func _ready() -> void:
	if not is_placed:
		BuildManager.current_preview = self
		modulate.a = 0.5
	else:
		# If placed, start listening for items in the pickup area
		pickup_area.area_entered.connect(_on_pickup_area_entered)

func _process(_delta: float) -> void:
	if is_placed:
		return
		
	var mouse_pos = get_global_mouse_position()
	var current_grid_cell = GridManager.world_to_grid(mouse_pos)
	global_position = GridManager.grid_to_world(current_grid_cell)

func _unhandled_input(event: InputEvent) -> void:
	if not is_placed:
		# Rotate preview
		if event is InputEventKey and event.keycode == KEY_R and event.pressed:
			rotation_degrees += 90
			current_direction = (current_direction + 1) % 4
			
		# Place building
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var current_grid_cell = GridManager.world_to_grid(get_global_mouse_position())
			var success = GridManager.place_item(current_grid_cell, self)
			
			if success:
				is_placed = true
				modulate.a = 1.0 
				pickup_area.area_entered.connect(_on_pickup_area_entered)
				
				var next_arm = load(scene_file_path).instantiate()
				next_arm.current_direction = current_direction
				next_arm.rotation_degrees = rotation_degrees
				get_parent().add_child(next_arm)
	else:
		# If the building IS placed, listen for F and B to manually test the arm
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_F:
				swing_arm_forward()
			elif event.keycode == KEY_B:
				swing_arm_back()

# --- AUTOMATED MOVEMENT LOGIC ---

func _on_pickup_area_entered(area: Area2D) -> void:
	if area.is_in_group("items") and not is_busy:
		# Use call_deferred to safely trigger the grab AFTER physics math is done
		call_deferred("grab_item", area)

func grab_item(item: Node2D) -> void:
	is_busy = true
	held_item = item
	
	item.remove_from_group("items")
	item.set_physics_process(false) 
	
	# --- NEW: Use Godot 4's reparent function! ---
	# Passing 'false' tells it NOT to keep its world position,
	# making it snap directly to the claw's local space.
	item.reparent(grab_point, false)
	item.position = Vector2.ZERO 
	
	swing_arm_forward()

func swing_arm_forward() -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(arm_sprite, "rotation_degrees", 180.0, swing_time)
	
	tween.tween_callback(drop_item)

func drop_item() -> void:
	if held_item:
		var main_level = get_tree().current_scene
		
		held_item.reparent(main_level)
		held_item.global_position = $DropArea.global_position
		
		# --- NEW: Tell the item it needs to yield to traffic! ---
		if "is_waiting_for_gap" in held_item:
			held_item.is_waiting_for_gap = true
		
		held_item.add_to_group("items")
		held_item.set_physics_process(true)
		
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
			grab_item(area)
			break # Stop checking after grabbing one
