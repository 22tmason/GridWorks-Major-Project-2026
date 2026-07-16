extends Node2D

# --- MATCHING STRAIGHT BELT VARIABLES ---
enum Direction { UP, RIGHT, DOWN, LEFT }
@export var current_direction: Direction = Direction.RIGHT
var is_placed := false
@export var speed: float = 128.0
var push_direction: Vector2 = Vector2.RIGHT

# (Assume your other onready vars and item arrays are here)

func _ready() -> void:
	if not is_placed:
		BuildManager.current_preview = self
		modulate.a = 0.5
	else:
		# (Connect your area signals here)
		pass

# --- NEW: 1x1 Building footprint ---
func get_occupied_cells(center_cell: Vector2i) -> Array[Vector2i]:
	return [center_cell]

func _process(_delta: float) -> void:
	if is_placed: return
		
	var mouse_pos = get_global_mouse_position()
	var current_grid_cell = GridManager.world_to_grid(mouse_pos)
	global_position = GridManager.grid_to_world(current_grid_cell)

	var cells_to_check = get_occupied_cells(current_grid_cell)
	
	if GridManager.is_placement_blocked(cells_to_check):
		modulate = Color(1.0, 0.4, 0.4, 0.8) # Red if blocked
	else:
		modulate = Color(1.0, 1.0, 1.0, 0.5) # White if clear
		
	# --- NEW: DRAG BUILDING LOGIC ---
	# If the mouse is currently held down, constantly attempt to place!
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		attempt_placement(current_grid_cell)

func _unhandled_input(event: InputEvent) -> void:
	if is_placed: return
		
	if event is InputEventKey and event.keycode == KEY_R and event.pressed:
		rotation_degrees += 90
		current_direction = (current_direction + 1) % 4 as Direction

# --- NEW: Dedicated placement function ---
func attempt_placement(target_cell: Vector2i) -> void:
	var cells_to_claim = get_occupied_cells(target_cell)
	
	# GridManager handles the check, so this will simply return false if we are 
	# hovering over an already-placed belt while dragging.
	if GridManager.place_item(cells_to_claim, self):
		is_placed = true
		modulate = Color(1.0, 1.0, 1.0, 1.0) 
		
		# (Activate your item collision areas here)
		
		# Spawn the next preview
		var next_belt = load(scene_file_path).instantiate()
		next_belt.current_direction = current_direction
		next_belt.rotation_degrees = rotation_degrees
		get_parent().add_child(next_belt)
