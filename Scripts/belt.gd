extends Area2D

enum Direction { UP, RIGHT, DOWN, LEFT }

@export var current_direction: Direction = Direction.DOWN 
var is_placed := false
var speed: float = 64.0 
var push_direction: Vector2 = Vector2.DOWN 
@export var lane_offset: float = 16.0 

func _ready() -> void:
	if not is_placed:
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
			
			var belt_scene = load("res://GridWorks Major Project 2026/Scenes/belt.tscn")
			var next_belt = belt_scene.instantiate()
			get_parent().add_child(next_belt)
			
			var current_sprite = $AnimatedSprite2D
			var next_sprite = next_belt.get_node("AnimatedSprite2D")
			
			# Sync the animation frame
			next_sprite.set_frame_and_progress(current_sprite.frame, current_sprite.frame_progress)
			
			# --- NEW: Sync the rotation variables to the next preview belt! ---
			next_belt.current_direction = current_direction
			next_belt.push_direction = push_direction
			next_sprite.rotation_degrees = current_sprite.rotation_degrees

# --- NEW: Helper function to manage math and visuals ---
func rotate_belt() -> void:
	# Cycle to the next direction in the enum (0 -> 1 -> 2 -> 3 -> 0)
	current_direction = (current_direction + 1) % 4 as Direction
	
	# Update the mathematical push direction and the sprite's visual rotation.
	# (Assuming 0 degrees is your default DOWN-pointing sprite)
	match current_direction:
		Direction.UP:
			push_direction = Vector2.UP
			$AnimatedSprite2D.rotation_degrees = 180
		Direction.RIGHT:
			push_direction = Vector2.RIGHT
			$AnimatedSprite2D.rotation_degrees = 270 # Or -90
		Direction.DOWN:
			push_direction = Vector2.DOWN
			$AnimatedSprite2D.rotation_degrees = 0
		Direction.LEFT:
			push_direction = Vector2.LEFT
			$AnimatedSprite2D.rotation_degrees = 90
