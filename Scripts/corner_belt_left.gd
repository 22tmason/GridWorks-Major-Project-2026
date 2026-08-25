extends Node2D

# --- BUILDING SYSTEM VARIABLES ---
enum Direction { UP, RIGHT, DOWN, LEFT }
@export var current_direction: Direction = Direction.DOWN 
var is_placed := false

# --- SPEED & ITEM VARIABLES ---
@export var speed: float = 128.0
@export var building_item_id: String = "corner_belt_left_mk1"

# --- CORNER BELT VARIABLES ---
@onready var my_path = $Path2D
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

func get_occupied_cells(center_cell: Vector2i) -> Array[Vector2i]:
	return [center_cell]

func _process(delta: float) -> void:
	# Animate arrows using pixel speed to match straight belts
	for follower in followers:
		follower.progress += speed * delta
		
	if is_placed: 
		return
	
	var mouse_pos = get_global_mouse_position()
	var current_grid_cell = GridManager.world_to_grid(mouse_pos)
	global_position = GridManager.grid_to_world(current_grid_cell)

	var cells_to_check = get_occupied_cells(current_grid_cell)
	
	if GridManager.is_placement_blocked(cells_to_check, building_item_id):
		modulate = Color(1.0, 0.4, 0.4, 0.8)
	else:
		modulate = Color(1.0, 1.0, 1.0, 0.5)

	# --- Continuous WASD Building ---
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		attempt_placement()

func _unhandled_input(event: InputEvent) -> void:
	if is_placed:
		return
		
	if event is InputEventKey and event.keycode == KEY_R and event.pressed:
		rotate_belt()
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		attempt_placement()

# --- EXTRACTED PLACEMENT LOGIC ---
func attempt_placement() -> void:
	# Prevent building while menus are open
	var inv_ui = get_tree().current_scene.get_node_or_null("InventoryUI")
	var machine_ui = get_tree().get_first_node_in_group("machine_ui")
	if (inv_ui and inv_ui.visible) or (machine_ui and machine_ui.visible):
		return

	if InventoryManager.get_item_count(building_item_id) <= 0:
		return
		
	var current_grid_cell = GridManager.world_to_grid(global_position)
	var cells_to_claim = get_occupied_cells(current_grid_cell)
	
	# Block placement if invalid
	if GridManager.is_placement_blocked(cells_to_claim, building_item_id):
		return
		
	var success = GridManager.place_item(cells_to_claim, self)
	if success:
		is_placed = true
		modulate = Color(1.0, 1.0, 1.0, 1.0)
		
		if has_node("EntranceArea"):
			$EntranceArea.is_placed = true
		if has_node("ExitArea"):
			$ExitArea.is_placed = true
		
		var next_belt = load(scene_file_path).instantiate()
		next_belt.current_direction = current_direction
		next_belt.rotation_degrees = rotation_degrees
		get_parent().add_child(next_belt)

func rotate_belt() -> void:
	current_direction = (current_direction + 1) % 4 as Direction
	rotation_degrees += 90

func make_perfect_quarter_circle() -> void:
	var perfect_curve = Curve2D.new()
	var radius: float = 32.0 
	var kappa: float = 0.5522847
	var handle_length: float = radius * kappa
	
	var start_pos = Vector2(radius, 0)
	var start_out = Vector2(-handle_length, 0)
	perfect_curve.add_point(start_pos, Vector2.ZERO, start_out)
	
	var end_pos = Vector2(0, radius) 
	var end_in = Vector2(0, -handle_length)
	perfect_curve.add_point(end_pos, end_in, Vector2.ZERO)
	
	my_path.curve = perfect_curve
	
func setup_multiple_arrows() -> void:
	var original_follower = $Path2D/PathFollow2D
	original_follower.loop = true
	followers.append(original_follower)
	
	for i in range(1, arrow_count):
		var new_follower = original_follower.duplicate()
		$Path2D.add_child(new_follower)
		followers.append(new_follower)
		
	for i in range(followers.size()):
		followers[i].progress_ratio = float(i) / arrow_count
