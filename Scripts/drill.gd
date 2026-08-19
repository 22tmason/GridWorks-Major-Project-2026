extends Node2D

# --- BUILDING SYSTEM VARIABLES ---
enum Direction { UP, RIGHT, DOWN, LEFT }
@export var current_direction: Direction = Direction.DOWN
var is_placed := false
var is_item_ready: bool = false

# --- ITEM COST ---
@export var building_item_id: String = ""

# --- DRILL VARIABLES ---
@export var mining_speed: float = 2.0 
@export var rotation_speed: float = 360.0 

@export_group("Resource Output Items")
@export var iron_item_scene: PackedScene   # Drag Iron Ore Item scene here
@export var copper_item_scene: PackedScene # Drag Copper Ore Item scene here

@onready var mining_timer: Timer = $MiningTimer
@onready var output_marker: Marker2D = $OutputMarker
@onready var output_check_area: Area2D = $OutputMarker/OutputCheckArea 
@onready var top_part: Sprite2D = $TopPart 

# --- STATUS ICON REFERENCE ---
@onready var status_icon: StatusIcon = $StatusIcon # Ensure child node is exactly named "StatusIcon"

# Will store "iron", "copper", or null
var active_resource = null 

func _ready() -> void:
	mining_timer.one_shot = true
	if not is_placed:
		BuildManager.current_preview = self
		modulate.a = 0.5
	else:
		_start_mining()

func get_occupied_cells(center_cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(-1, 2): 
		for y in range(-1, 2): 
			cells.append(center_cell + Vector2i(x, y))
	return cells

func _find_resource_under_drill(occupied_cells: Array[Vector2i]) -> String:
	for cell in occupied_cells:
		var raw_res = GridManager.get_resource_at_cell(cell)
		if raw_res != "":
			if "iron" in raw_res: 
				return "iron"
			if "copper" in raw_res: 
				return "copper"
	return ""

func _process(delta: float) -> void:
	if is_placed:
		var is_stuck = is_item_ready and is_output_blocked()
		
		# --- STATUS ICON UPDATE LOGIC ---
		if status_icon:
			if active_resource == "" or active_resource == null:
				status_icon.set_status(StatusIcon.Status.NO_INPUT) # Placed on empty ground (nothing to mine)
			elif is_stuck:
				status_icon.set_status(StatusIcon.Status.OUTPUT_FULL) # Conveyor or output is blocked
			else:
				status_icon.set_status(StatusIcon.Status.WORKING) # Spinning normally, hide icon
		
		if not is_stuck:
			top_part.rotation_degrees += rotation_speed * delta
		return
		
	var current_grid_cell = GridManager.world_to_grid(get_global_mouse_position())
	global_position = GridManager.grid_to_world(current_grid_cell)

	var cells_to_check = get_occupied_cells(current_grid_cell)
	if GridManager.is_placement_blocked(cells_to_check) or InventoryManager.get_item_count(building_item_id) <= 0:
		modulate = Color(1.0, 0.4, 0.4, 0.8)
	else:
		modulate = Color(1.0, 1.0, 1.0, 0.5)

func _unhandled_input(event: InputEvent) -> void:
	if is_placed:
		return
		
	if event is InputEventKey and event.keycode == KEY_R and event.pressed:
		rotate_drill()
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		attempt_placement()
		
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		attempt_placement()

func rotate_drill() -> void:
	current_direction = (current_direction + 1) % 4 as Direction
	rotation_degrees += 90

func attempt_placement() -> void:
	if InventoryManager.get_item_count(building_item_id) <= 0:
		return
		
	var current_grid_cell = GridManager.world_to_grid(get_global_mouse_position())
	var cells_to_claim = get_occupied_cells(current_grid_cell)
	
	if GridManager.is_placement_blocked(cells_to_claim):
		return
		
	var success = GridManager.place_item(cells_to_claim, self)
	if success:
		global_position = GridManager.grid_to_world(current_grid_cell)
		is_placed = true
		modulate = Color(1.0, 1.0, 1.0, 1.0)
		
		# Identify underlying resource deposit
		active_resource = _find_resource_under_drill(cells_to_claim)
		
		# Start mining logic
		_start_mining()
		
		# Spawn next preview
		var next_building = BuildManager.selected_scene.instantiate()
		get_parent().add_child(next_building)
		next_building.rotation_degrees = rotation_degrees
		if "current_direction" in next_building:
			next_building.current_direction = current_direction

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
	var scene_to_spawn: PackedScene = null
	if active_resource == "iron":
		scene_to_spawn = iron_item_scene
	elif active_resource == "copper":
		scene_to_spawn = copper_item_scene
		
	if not scene_to_spawn:
		return

	if not is_output_blocked():
		var new_item = scene_to_spawn.instantiate()
		new_item.global_position = output_marker.global_position
		get_parent().add_child(new_item)
		
		# Notify tutorial
		if "item_id" in new_item and get_node_or_null("/root/TutorialManager"):
			TutorialManager.notify_item_produced(new_item.item_id)
			
		is_item_ready = false
		_start_mining()
