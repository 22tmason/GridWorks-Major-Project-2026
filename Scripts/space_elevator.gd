extends Node2D

# --- PHASE & STORAGE VARIABLES ---
signal phase_completed(phase_index: int)
signal item_delivered(item_id: String, current_amount: int, required_amount: int)

var current_phase: int = 0

# Dictionary array mapping each phase to required item counts
@export var phase_requirements: Array[Dictionary] = [
	{"iron_plate": 100, "copper_plate": 100}, # Phase 0
	{"iron_gear": 200, "copper_wire": 200, "iron_rod": 100}, # Phase 1
	{"electronic_circuit": 200, "engine": 100, "steel_plate": 50}, # Phase 2
	{"plastic_bar": 150, "advanced_circuit": 100, "low_density_structure": 100}, # Phase 3
	{"processing_circuit": 100, "flying_robot_frame": 50, "low_density_structure": 50}, # Phase 4
	{"rocket_control_unit": 100, "low_density_structure": 150, "flying_robot_frame": 75}, # Phase 5
]

# Tracks items collected for the active phase: { "item_id": count }
var current_deliveries: Dictionary = {}

@onready var input_area: Area2D = $Area2D

func _ready() -> void:
	add_to_group("space_elevator") # --- NEW: Tag the elevator so the compass can find it ---
	
	input_area.area_entered.connect(_on_item_entered)
	input_area.input_pickable = true
	input_area.input_event.connect(_on_machine_clicked)
	
	_init_phase_tracker()
	
	# Automatically claim its 5x5 grid footprint on initial scene load
	call_deferred("_register_fixed_footprint")

func _register_fixed_footprint() -> void:
	var center_cell = GridManager.world_to_grid(global_position)
	var occupied_cells = get_occupied_cells(center_cell)
	GridManager.place_item(occupied_cells, self)

# --- 5x5 MULTI-TILE GRID CALCULATION (PERFECTLY CENTERED) ---
func get_occupied_cells(center_cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(-2, 3):
		for y in range(-2, 3):
			cells.append(center_cell + Vector2i(x, y))
	return cells

func _init_phase_tracker() -> void:
	current_deliveries.clear()
	if current_phase < phase_requirements.size():
		var active_reqs = phase_requirements[current_phase]
		for item_id in active_reqs.keys():
			current_deliveries[item_id] = 0

func _physics_process(_delta: float) -> void:
	_check_for_waiting_items()

# --- ITEM ABSORPTION LOGIC ---
func _is_item_needed(item_id: String) -> bool:
	if current_phase >= phase_requirements.size():
		return false
		
	var active_reqs = phase_requirements[current_phase]
	if not active_reqs.has(item_id):
		return false
		
	var current_amt: int = current_deliveries.get(item_id, 0)
	var required_amt: int = active_reqs[item_id]
	
	return current_amt < required_amt

func _try_absorb_item(area: Area2D) -> bool:
	if area.is_queued_for_deletion() or not area.is_in_group("items"):
		return false
		
	if not "item_id" in area:
		return false
		
	var item_id: String = area.item_id
	if _is_item_needed(item_id):
		current_deliveries[item_id] = current_deliveries.get(item_id, 0) + 1
		
		var req_amt: int = phase_requirements[current_phase][item_id]
		item_delivered.emit(item_id, current_deliveries[item_id], req_amt)
		
		# --- NEW: Tell the TutorialManager an item was delivered! ---
		if get_node_or_null("/root/TutorialManager"):
			TutorialManager.notify_item_delivered(item_id)
		
		area.queue_free()
		return true
		
	return false

func _on_item_entered(area: Area2D) -> void:
	_try_absorb_item(area)

func _check_for_waiting_items() -> void:
	for area in input_area.get_overlapping_areas():
		_try_absorb_item(area)

func is_phase_ready_to_seal() -> bool:
	if current_phase >= phase_requirements.size():
		return false
		
	var active_reqs = phase_requirements[current_phase]
	for item_id in active_reqs.keys():
		if current_deliveries.get(item_id, 0) < active_reqs[item_id]:
			return false
	return true

func seal_phase() -> void:
	if not is_phase_ready_to_seal():
		return
		
	phase_completed.emit(current_phase)
	current_phase += 1
	ProgressionManager.advance_phase()
	_init_phase_tracker()

# --- UI HOOK ---
func _on_machine_clicked(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var ui = get_tree().get_first_node_in_group("machine_ui")
		if ui:
			ui.open_ui(self)
