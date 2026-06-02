extends Node2D

enum Direction { UP, RIGHT, DOWN, LEFT }

@export var current_direction: Direction = Direction.DOWN 
var is_placed := false

func _ready() -> void:
	if not is_placed:
		BuildManager.current_preview = self
		modulate.a = 0.5

func _process(_delta: float) -> void:
	if is_placed:
		return
		
	var mouse_pos = get_global_mouse_position()
	var current_grid_cell = GridManager.world_to_grid(mouse_pos)
	var snapped_position = GridManager.grid_to_world(current_grid_cell)
	
	global_position = snapped_position

func _unhandled_input(event: InputEvent) -> void:
	if is_placed:
		return
		
	if event is InputEventKey and event.keycode == KEY_R and event.pressed:
		rotate_belt()
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var current_grid_cell = GridManager.world_to_grid(get_global_mouse_position())
		var success = GridManager.place_item(current_grid_cell, self)
		
		if success:
			is_placed = true
			modulate.a = 1.0 
			
			# Activate the child areas so the item recognizes them!
			if has_node("EntranceArea"):
				$EntranceArea.is_placed = true
			if has_node("ExitArea"):
				$ExitArea.is_placed = true
			
			var next_belt = BuildManager.selected_scene.instantiate()
			var current_sprite = $AnimatedSprite2D
			var next_sprite = next_belt.get_node("AnimatedSprite2D")
			
			next_sprite.set_frame_and_progress(current_sprite.frame, current_sprite.frame_progress)
			
			next_belt.current_direction = current_direction
			next_belt.rotation_degrees = rotation_degrees
			
			get_parent().add_child(next_belt)

func rotate_belt() -> void:
	current_direction = (current_direction + 1) % 4 as Direction
	rotation_degrees += 90
