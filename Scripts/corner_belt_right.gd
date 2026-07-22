extends Node2D

# --- BUILDING SYSTEM VARIABLES ---
enum Direction { UP, RIGHT, DOWN, LEFT }
@export var current_direction: Direction = Direction.DOWN 
var is_placed := false

# --- NEW: Identify what item this building costs ---
@export var building_item_id: String = "corner_belt_right"

# --- CORNER BELT VARIABLES ---
@onready var my_path = $Path2D
@export var animation_speed: float = 0.5 
@export var arrow_count: int = 3
var followers: Array[PathFollow2D] = []

func _ready() -> void:
	if not is_placed:
		BuildManager.current_preview = self
		modulate.a = 0.5 
		
	# NEW ORIENTATION: Enters moving RIGHT, exits moving DOWN
	if has_node("EntranceArea"):
		$EntranceArea.push_direction = Vector2(1, 0)
	if has_node("ExitArea"):
		$ExitArea.push_direction = Vector2(0, 1)
		
	# Build the perfect curve and setup the arrows
	make_perfect_quarter_circle()
	setup_multiple_arrows()

# --- NEW: 1x1 Building footprint ---
func get_occupied_cells(center_cell: Vector2i) -> Array[Vector2i]:
	return [center_cell]

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

	# --- NEW: Universal Red/White Overlay Check ---
	var cells_to_check = get_occupied_cells(current_grid_cell)
	
	# GridManager checks if the physical space is clear AND if inventory has stock
	if GridManager.is_placement_blocked(cells_to_check, building_item_id):
		modulate = Color(1.0, 0.4, 0.4, 0.8) # Red if blocked
	else:
		modulate = Color(1.0, 1.0, 1.0, 0.5) # White if clear

func _unhandled_input(event: InputEvent) -> void:
	if is_placed:
		return
		
	if event is InputEventKey and event.keycode == KEY_R and event.pressed:
		rotate_belt()
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var current_grid_cell = GridManager.world_to_grid(global_position)
		
		# --- UPDATED: Pass the ARRAY of cells to the GridManager! ---
		var cells_to_claim = get_occupied_cells(current_grid_cell)
		
		# GridManager now handles checking the inventory AND deducting the item!
		var success = GridManager.place_item(cells_to_claim, self)
		
		if success:
			is_placed = true
			modulate = Color(1.0, 1.0, 1.0, 1.0) # Reset color fully back to normal
			
			# Activate the child areas so the item recognizes them!
			if has_node("EntranceArea"):
				$EntranceArea.is_placed = true
			if has_node("ExitArea"):
				$ExitArea.is_placed = true
			
			# Spawn the next preview
			var next_belt = load(scene_file_path).instantiate()
			next_belt.current_direction = current_direction
			next_belt.rotation_degrees = rotation_degrees
			get_parent().add_child(next_belt)

func rotate_belt() -> void:
	current_direction = (current_direction + 1) % 4 as Direction
	rotation_degrees += 90

# --- MATH AND ANIMATION ---
func make_perfect_quarter_circle() -> void:
	var perfect_curve = Curve2D.new()
	
	# --- Widen the curve to match your 64x64 tile edges! ---
	var radius: float = 32.0 
	var kappa: float = 0.5522847
	var handle_length: float = radius * kappa
	
	# Point 0: The Entrance (Left side edge, moving right)
	var start_pos = Vector2(-radius, 0)
	var start_out = Vector2(handle_length, 0)
	perfect_curve.add_point(start_pos, Vector2.ZERO, start_out)
	
	# Point 1: The Exit (Bottom edge, moving down)
	var end_pos = Vector2(0, radius)
	var end_in = Vector2(0, -handle_length)
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
