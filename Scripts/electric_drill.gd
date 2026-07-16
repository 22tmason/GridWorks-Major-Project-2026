extends Node2D

# --- BUILDING SYSTEM VARIABLES ---
enum Direction { UP, RIGHT, DOWN, LEFT }
@export var current_direction: Direction = Direction.DOWN
var is_placed := false
var is_item_ready: bool = false

# --- DRILL VARIABLES ---
@export var mining_speed: float = 2.0 
@export var rotation_speed: float = 360.0 
@export var item_scene: PackedScene   

@onready var mining_timer: Timer = $MiningTimer
@onready var output_marker: Marker2D = $OutputMarker
@onready var output_check_area: Area2D = $OutputMarker/OutputCheckArea 
@onready var top_part: Sprite2D = $TopPart 

var active_resource = null 

func _ready() -> void:
	mining_timer.one_shot = true
	if not is_placed:
		BuildManager.current_preview = self
		modulate.a = 0.5
	else:
		_start_mining()

# --- NEW: HELPER FOR 3x3 BUILDINGS ---
# Calculates the 9 grid cells this drill covers based on its center cell
func get_occupied_cells(center_cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(-1, 2): # -1, 0, 1
		for y in range(-1, 2): # -1, 0, 1
			cells.append(center_cell + Vector2i(x, y))
	return cells

func _process(delta: float) -> void:
	if is_placed:
		var is_stuck = is_item_ready and is_output_blocked()
		if not is_stuck:
			top_part.rotation_degrees += rotation_speed * delta
		return
		
	var mouse_pos = get_global_mouse_position()
	var current_grid_cell = GridManager.world_to_grid(mouse_pos)
	var snapped_position = GridManager.grid_to_world(current_grid_cell)
	
	global_position = snapped_position

	# --- 3x3 PREVIEW CHECK ---
	var occupied_cells = get_occupied_cells(current_grid_cell)
	var is_blocked = false
	
	# Check if ANY of the 9 cells are already full
	for cell in occupied_cells:
		if GridManager.grid_data.has(cell):
			is_blocked = true
			break
			
	if is_blocked:
		modulate = Color(1.0, 0.4, 0.4, 0.8) # Red: At least 1 cell is blocked!
	else:
		modulate = Color(1.0, 1.0, 1.0, 0.5) # White: All 9 cells are clear!

func _unhandled_input(event: InputEvent) -> void:
	if is_placed:
		return
		
	if event is InputEventKey and event.keycode == KEY_R and event.pressed:
		rotate_drill()
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var current_grid_cell = GridManager.world_to_grid(get_global_mouse_position())
		var occupied_cells = get_occupied_cells(current_grid_cell)
		
		# 1. Final Safety Check: Make sure no tiles are blocked before placing
		for cell in occupied_cells:
			if GridManager.grid_data.has(cell):
				return # Exit instantly! Do not place the building.
		
		# 2. Claim all 9 tiles in the Grid Manager!
		for cell in occupied_cells:
			GridManager.grid_data[cell] = self
		
		print("Successfully placed 3x3 Drill at center: ", current_grid_cell)
		
		is_placed = true
		modulate = Color(1.0, 1.0, 1.0, 1.0) 
		_start_mining()
		
		var next_drill = BuildManager.selected_scene.instantiate()
		if "current_direction" in next_drill:
			next_drill.current_direction = current_direction
		next_drill.rotation_degrees = rotation_degrees
		get_parent().add_child(next_drill)

func rotate_drill() -> void:
	current_direction = (current_direction + 1) % 4 as Direction
	rotation_degrees += 90

# --- MINING LOGIC ---
func _start_mining() -> void:
	mining_timer.wait_time = mining_speed
	if not mining_timer.timeout.is_connected(_on_mining_finished):
		mining_timer.timeout.connect(_on_mining_finished)
	mining_timer.start()

func _on_mining_finished() -> void:
	is_item_ready = true

func _physics_process(_delta: float) -> void:
	if not is_placed: 
		return
	if is_item_ready:
		_try_spawn_item()

func is_output_blocked() -> bool:
	var overlapping_things = output_check_area.get_overlapping_areas()
	for thing in overlapping_things:
		if thing.is_in_group("items"):
			return true 
	return false 
		
func _try_spawn_item() -> void:
	if not item_scene:
		push_error("Drill has no Item Scene assigned!")
		return
		
	if is_output_blocked():
		return
			
	var new_item = item_scene.instantiate()
	new_item.global_position = output_marker.global_position
	get_tree().current_scene.add_child(new_item)
	
	is_item_ready = false
	mining_timer.start()
