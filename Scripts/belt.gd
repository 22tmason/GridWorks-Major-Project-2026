extends Area2D

enum Direction { UP, RIGHT, DOWN, LEFT }

@export var current_direction: Direction = Direction.DOWN 
var is_placed := false
@export var speed: float = 128.0
var push_direction: Vector2 = Vector2.DOWN 
@export var lane_offset: float = 16.0 

func _ready() -> void:
	if not is_placed:
		BuildManager.current_preview = self
		modulate.a = 0.5

func get_occupied_cells(center_cell: Vector2i) -> Array[Vector2i]:
	return [center_cell]

func _process(_delta: float) -> void:
	if is_placed:
		return
		
	var current_grid_cell = GridManager.world_to_grid(get_global_mouse_position())
	global_position = GridManager.grid_to_world(current_grid_cell)

	var cells_to_check = get_occupied_cells(current_grid_cell)
	
	if GridManager.is_placement_blocked(cells_to_check):
		modulate = Color(1.0, 0.4, 0.4, 0.8) # Red if blocked
	else:
		modulate = Color(1.0, 1.0, 1.0, 0.5) # White if clear

func _unhandled_input(event: InputEvent) -> void:
	if is_placed:
		return
		
	if event is InputEventKey and event.keycode == KEY_R and event.pressed:
		rotate_belt()
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var current_grid_cell = GridManager.world_to_grid(get_global_mouse_position())
		var cells_to_claim = get_occupied_cells(current_grid_cell)
		var success = GridManager.place_item(cells_to_claim, self)
		
		if success:
			is_placed = true
			modulate = Color(1.0, 1.0, 1.0, 1.0) # Reset fully back to normal color
			
			var next_belt = BuildManager.selected_scene.instantiate()
			get_parent().add_child(next_belt)
			
			var current_sprite = get_node_or_null("AnimatedSprite2D")
			var next_sprite = next_belt.get_node_or_null("AnimatedSprite2D")
			
			# Animation Sync
			if current_sprite != null and next_sprite != null:
				next_sprite.set_frame_and_progress(current_sprite.frame, current_sprite.frame_progress)
			
			# Rotation Sync
			next_belt.rotation_degrees = rotation_degrees
			if "current_direction" in next_belt: 
				next_belt.current_direction = current_direction

func rotate_belt() -> void:
	current_direction = (current_direction + 1) % 4 as Direction
	rotation_degrees += 90
