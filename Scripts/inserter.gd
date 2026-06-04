extends Node2D

@onready var arm_sprite = $ArmSprite
@onready var pickup_area = $PickupArea
@onready var grab_point = $ArmSprite/GrabPoint

# State variables
var is_placed := false
var current_direction := 0 # Prevents the BuildManager crash!
var held_item: Node2D = null
@export var swing_time: float = 0.5 # Time in seconds it takes to swing

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
	# Check if we are empty-handed and if the thing that entered is actually an item
	if held_item == null and area.is_in_group("items"):
		grab_item(area)

func grab_item(item: Node2D) -> void:
	held_item = item
	
	# Optional: Disable the item's own movement script here so it stops trying to ride the belt
	# item.set_process(false) 
	
	# Snap the item to the arm's claw
	item.get_parent().remove_child(item)
	grab_point.add_child(item)
	item.position = Vector2.ZERO 
	
	swing_arm_forward()

func swing_arm_forward() -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(arm_sprite, "rotation_degrees", 180.0, swing_time)
	
	# When the tween finishes swinging, trigger the drop_item function
	tween.tween_callback(drop_item)

func drop_item() -> void:
	if held_item:
		# Unparent from the arm and put it back into the main world
		var main_level = get_tree().current_scene
		grab_point.remove_child(held_item)
		main_level.add_child(held_item)
		
		# Set the item's global position to exactly where the DropArea is
		held_item.global_position = $DropArea.global_position
		
		# Optional: Re-enable the item's movement here
		# held_item.set_process(true)
		
		held_item = null
		swing_arm_back()

func swing_arm_back() -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(arm_sprite, "rotation_degrees", 0.0, swing_time)
