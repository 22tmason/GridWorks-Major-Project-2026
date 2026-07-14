extends Node2D

# --- BUILDING SYSTEM VARIABLES ---
enum Direction { UP, RIGHT, DOWN, LEFT }
@export var current_direction: Direction = Direction.DOWN 
var is_placed := false

# --- CORNER BELT VARIABLES ---
@onready var my_path = $Path2D
@export var animation_speed: float = 0.5 
@export var arrow_count: int = 3
var followers: Array[PathFollow2D] = []

func _ready() -> void:
	if not is_placed:
		BuildManager.current_preview = self
		modulate.a = 0.5 
		
	# NEW ORIENTATION: Enters from the RIGHT (moving left), exits BOTTOM (moving down)
	if has_node("EntranceArea"):
		$EntranceArea.push_direction = Vector2(-1, 0) # Pushing LEFT
	if has_node("ExitArea"):
		$ExitArea.push_direction = Vector2(0, 1)  # Pushing DOWN
		
	make_perfect_quarter_circle()
	setup_multiple_arrows()

func _process(delta: float) -> void:
	# Animate all arrows constantly
	for follower in followers:
		follower.progress_ratio += animation_speed * delta
		
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
			
			# --- Use your BuildManager exactly like the old code! ---
			var next_belt = BuildManager.selected_scene.instantiate()
			
			# Safely pass direction to the next belt (in case you swap to an inserter)
			if "current_direction" in next_belt:
				next_belt.current_direction = current_direction
			
			next_belt.rotation_degrees = rotation_degrees
			
			get_parent().add_child(next_belt)

func rotate_belt() -> void:
	current_direction = (current_direction + 1) % 4 as Direction
	rotation_degrees += 90

# --- MATH AND ANIMATION ---
func make_perfect_quarter_circle() -> void:
	var perfect_curve = Curve2D.new()
	var radius: float = 32.0 
	var kappa: float = 0.5522847
	var handle_length: float = radius * kappa
	
	# Point 0: The Entrance (Right side edge, moving left)
	var start_pos = Vector2(radius, 0)
	var start_out = Vector2(-handle_length, 0) # Handle points left
	perfect_curve.add_point(start_pos, Vector2.ZERO, start_out)
	
	# Point 1: The Exit (Bottom edge, moving down)
	var end_pos = Vector2(0, radius) 
	var end_in = Vector2(0, -handle_length) # Handle points up to smooth the curve
	perfect_curve.add_point(end_pos, end_in, Vector2.ZERO)
	
	my_path.curve = perfect_curve
	
func setup_multiple_arrows() -> void:
	var original_follower = $Path2D/PathFollow2D
	original_follower.loop = true # Ensure Godot knows to wrap the math
	followers.append(original_follower)
	
	# Duplicate the follower to create the exact amount of arrows you want
	for i in range(1, arrow_count):
		var new_follower = original_follower.duplicate()
		$Path2D.add_child(new_follower)
		followers.append(new_follower)
		
	# Evenly space them out mathematically along the path
	for i in range(followers.size()):
		followers[i].progress_ratio = float(i) / arrow_count
