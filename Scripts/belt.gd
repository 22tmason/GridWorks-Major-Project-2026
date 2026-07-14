extends Area2D

enum Direction { UP, RIGHT, DOWN, LEFT }

@export var current_direction: Direction = Direction.DOWN 
var is_placed := false
@export var speed: float = 128
var push_direction: Vector2 = Vector2.DOWN 
@export var lane_offset: float = 16.0 

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
		
	# --- NEW: Press "R" to rotate the preview belt ---
	if event is InputEventKey and event.keycode == KEY_R and event.pressed:
		rotate_belt()
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var current_grid_cell = GridManager.world_to_grid(get_global_mouse_position())
		var success = GridManager.place_item(current_grid_cell, self)
		
		if success:
			is_placed = true
			modulate.a = 1.0 
			
			var next_belt = BuildManager.selected_scene.instantiate()
			get_parent().add_child(next_belt)
			
			var current_sprite = get_node_or_null("AnimatedSprite2D")
			var next_sprite = next_belt.get_node_or_null("AnimatedSprite2D")
			
			# Only try to sync the animation if BOTH objects actually have an AnimatedSprite2D
			if current_sprite != null and next_sprite != null:
				next_sprite.set_frame_and_progress(current_sprite.frame, current_sprite.frame_progress)
			
			# --- NEW: Sync the rotation! ---
			# Instead of transferring local Vector2s, just transfer the node's physical rotation
			next_belt.rotation_degrees = rotation_degrees
			if "current_direction" in next_belt: # Safe check in case you place something without this variable
				next_belt.current_direction = current_direction

func rotate_belt() -> void:
	# Keep your enum for logic/saving if you need it
	current_direction = (current_direction + 1) % 4 as Direction
	
	# Just physically rotate the whole root node by 90 degrees.
	rotation_degrees += 90
