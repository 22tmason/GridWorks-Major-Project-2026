extends Node2D

# --- BUILDING SYSTEM VARIABLES ---
enum Direction { UP, RIGHT, DOWN, LEFT }
@export var current_direction: Direction = Direction.DOWN
var is_placed := false
var is_item_ready: bool = false

# --- NEW: Identify what item this building costs ---
@export var building_item_id: String = "electric_drill"

# --- DRILL VARIABLES ---
@export var mining_speed: float = 2.0 
@export var rotation_speed: float = 360.0 

@export_group("Resource Output Items")
@export var iron_item_scene: PackedScene   # Drag your Iron Ore Item scene here
@export var copper_item_scene: PackedScene # Drag your Copper Ore Item scene here

@onready var mining_timer: Timer = $MiningTimer
@onready var output_marker: Marker2D = $OutputMarker
@onready var output_check_area: Area2D = $OutputMarker/OutputCheckArea 
@onready var top_part: Sprite2D = $TopPart 

# Will store "iron", "copper", or null
var active_resource = null 

func _ready() -> void:
	mining_timer.one_shot = true
	if not is_placed:
		BuildManager.current_preview = self
		modulate.a = 0.5
	else:
		_start_mining()

# Calculates the 9 grid cells this drill covers based on its center cell
func get_occupied_cells(center_cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(-1, 2): 
		for y in range(-1, 2): 
			cells.append(center_cell + Vector2i(x, y))
	return cells

# Helper function to check what resource is beneath the drill
func _find_resource_under_drill(occupied_cells: Array[Vector2i]) -> String:
	for cell in occupied_cells:
		var raw_res = GridManager.get_resource_at_cell(cell)
			
		# Map both core and thin edge tiles to a clean asset identifier string
		if raw_res != "":
			if "iron" in raw_res: 
				return "iron"
			if "copper" in raw_res: 
				return "copper"
				
	return "" # Return blank if no resource was encountered

func _process(delta: float) -> void:
	if is_placed:
		var is_stuck = is_item_ready and is_output_blocked()
		if not is_stuck:
			top_part.rotation_degrees += rotation_speed * delta
		return
		
	var mouse_pos = get_global_mouse_position()
	var current_grid_cell = GridManager.world_to_grid(mouse_pos)
	global_position = GridManager.grid_to_world(current_grid_cell)

	# --- 3x3 PREVIEW CHECK WITH RESOURCE VALIDATION ---
	var occupied_cells = get_occupied_cells(current_grid_cell)
	var detected_resource = _find_resource_under_drill(occupied_cells)
	
	# GridManager handles checking blockages and stock. We also require a resource!
	if GridManager.is_placement_blocked(occupied_cells, building_item_id) or detected_resource == "":
		modulate = Color(1.0, 0.4, 0.4, 0.8) # Red visual indicator
	else:
		modulate = Color(0.4, 1.0, 0.4, 0.6) # Green visual indicator: Good to go!

func _unhandled_input(event: InputEvent) -> void:
	if is_placed:
		return
		
	if event is InputEventKey and event.keycode == KEY_R and event.pressed:
		rotate_drill()
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var current_grid_cell = GridManager.world_to_grid(get_global_mouse_position())
		var occupied_cells = get_occupied_cells(current_grid_cell)
		
		# 1. Custom Check: Must be on a resource field!
		var detected_resource = _find_resource_under_drill(occupied_cells)
		if detected_resource == "":
			print("Placement failed: Drills must be built on a resource field!")
			return 
		
		# 2. GridManager handles grid-claiming AND inventory deduction!
		var success = GridManager.place_item(occupied_cells, self)
		
		if success:
			# Lock in resource type 
			active_resource = detected_resource
			print("Successfully placed 3x3 ", active_resource, " Drill at: ", current_grid_cell)
			
			is_placed = true
			modulate = Color(1.0, 1.0, 1.0, 1.0) 
			_start_mining()
			
			# Spawn the next blueprint preview instance
			var next_drill = load(scene_file_path).instantiate()
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
	# Select item based on active resource type
	var scene_to_spawn: PackedScene = null
	if active_resource == "iron":
		scene_to_spawn = iron_item_scene
	elif active_resource == "copper":
		scene_to_spawn = copper_item_scene
		
	if not scene_to_spawn:
		push_error("Drill is trying to output but has no matching item scene assigned!")
		return
		
	if is_output_blocked():
		return
			
	var new_item = scene_to_spawn.instantiate()
	new_item.global_position = output_marker.global_position
	get_tree().current_scene.add_child(new_item)
	
	is_item_ready = false
	mining_timer.start()
