extends Area2D

enum Direction { UP, RIGHT, DOWN, LEFT }

# Defaulting to DOWN since your Yellow Belt sprite points down!
@export var current_direction: Direction = Direction.DOWN 

# Tracks whether this specific belt is locked onto the factory floor
var is_placed := false

# Movement configuration for items to read
var speed: float = 64.0 
var push_direction: Vector2 = Vector2.DOWN 

# Distance from the center of the belt to the center of each lane
@export var lane_offset: float = 16.0 

func _ready() -> void:
	# Make the belt semi-transparent while we are just holding it as a preview
	if not is_placed:
		modulate.a = 0.5

func _process(_delta: float) -> void:
	# If it's already built, stop following the mouse!
	if is_placed:
		return
		
	var mouse_pos = get_global_mouse_position()
	var current_grid_cell = GridManager.world_to_grid(mouse_pos)
	var snapped_position = GridManager.grid_to_world(current_grid_cell)
	
	global_position = snapped_position

func _unhandled_input(event: InputEvent) -> void:
	if is_placed:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var current_grid_cell = GridManager.world_to_grid(get_global_mouse_position())
		var success = GridManager.place_item(current_grid_cell, self)
		
		if success:
			is_placed = true
			modulate.a = 1.0 
			
			# 1. Load the blueprint of the belt scene
			var belt_scene = load("res://GridWorks Major Project 2026/Scenes/belt.tscn")
			
			# 2. Create a brand new copy (instance) of it
			var next_belt = belt_scene.instantiate()
			
			# 3. Add it to the main level tree
			get_parent().add_child(next_belt)
			
			# --- Sync the animation! ---
			var current_sprite = $AnimatedSprite2D
			var next_sprite = next_belt.get_node("AnimatedSprite2D")
			next_sprite.set_frame_and_progress(current_sprite.frame, current_sprite.frame_progress)
