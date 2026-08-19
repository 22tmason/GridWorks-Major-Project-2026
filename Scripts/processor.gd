extends Node2D

# --- SPRITE REFERENCES ---
@onready var processor_off: Sprite2D = $ProcessorOff
@onready var glow_sprite: Sprite2D = $GlowSprite

# --- STATE VARIABLE ---
var is_processing := false:
	set(value):
		is_processing = value
		_update_sprite_visibility()
			
# --- BUILDING SYSTEM VARIABLES ---
enum Direction { UP, RIGHT, DOWN, LEFT }
@export var current_direction: Direction = Direction.DOWN
var is_placed := false

# --- ITEM COST ---
@export var building_item_id: String = "processor_mk1"

# --- RECIPE & STORAGE VARIABLES ---
@export var processing_time: float = 2.0 
@export var max_storage: int = 10 

@export var selected_recipe: String = ""
@export var recipes: Dictionary = {}             # "output_item_id" : PackedScene
@export var recipe_requirements: Dictionary = {} # "output_item_id" : {"input_item_id": amount}

var input_buffer: Array[String] = []
var output_buffer: Array[PackedScene] = []

@onready var processing_timer: Timer = $ProcessingTimer
@onready var input_area: Area2D = $InputArea
@onready var output_marker: Marker2D = $OutputMarker
@onready var output_check_area: Area2D = $OutputMarker/OutputCheckArea
@export var recipe_times: Dictionary = {}        # "output_item_id" : duration_in_seconds (float)
var current_output_scene: PackedScene = null 

func _ready() -> void:
	processing_timer.one_shot = true
	processing_timer.timeout.connect(_on_processing_finished)
	input_area.area_entered.connect(_on_item_entered)
	
	# Make the Processor clickable for recipe selection UI
	input_area.input_pickable = true
	input_area.input_event.connect(_on_machine_clicked)
	
	_update_sprite_visibility()
	
	if not is_placed:
		BuildManager.current_preview = self
		modulate.a = 0.5

func _update_sprite_visibility() -> void:
	if processor_off and glow_sprite:
		glow_sprite.visible = is_processing
		processor_off.visible = not is_processing

func get_occupied_cells(center_cell: Vector2i) -> Array[Vector2i]:
	return [
		center_cell,
		center_cell + Vector2i(1, 0),
		center_cell + Vector2i(0, 1),
		center_cell + Vector2i(1, 1)
	]

func _process(_delta: float) -> void:
	if is_placed:
		return
		
	var current_grid_cell = GridManager.world_to_grid(get_global_mouse_position())
	global_position = GridManager.grid_to_world(current_grid_cell) + Vector2(32.0, 32.0)
	
	var cells_to_check = get_occupied_cells(current_grid_cell)
	if GridManager.is_placement_blocked(cells_to_check) or InventoryManager.get_item_count(building_item_id) <= 0:
		modulate = Color(1.0, 0.4, 0.4, 0.8)
	else:
		modulate = Color(1.0, 1.0, 1.0, 0.5)

func _unhandled_input(event: InputEvent) -> void:
	if is_placed:
		return
		
	if event is InputEventKey and event.keycode == KEY_R and event.pressed:
		rotate_building()
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		attempt_placement()
		
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		attempt_placement()

func rotate_building() -> void:
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
		global_position = GridManager.grid_to_world(current_grid_cell) + Vector2(32.0, 32.0)
		is_placed = true
		modulate = Color(1.0, 1.0, 1.0, 1.0)
		
		var next_building = BuildManager.selected_scene.instantiate()
		get_parent().add_child(next_building)
		next_building.rotation_degrees = rotation_degrees
		if "current_direction" in next_building:
			next_building.current_direction = current_direction

func _physics_process(_delta: float) -> void:
	if not is_placed:
		return
		
	_try_start_processing()
	_try_empty_output_buffer()
	_check_for_waiting_items()

func is_output_blocked() -> bool:
	var overlapping_things = output_check_area.get_overlapping_areas()
	for thing in overlapping_things:
		if thing.is_in_group("items"):
			return true 
	return false

# --- RECIPE UI SELECTION ---
func _on_machine_clicked(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if is_placed and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var ui = get_tree().get_first_node_in_group("machine_ui")
		if ui:
			ui.open_ui(self)

func set_active_recipe(recipe_id: String) -> void:
	selected_recipe = recipe_id
	input_buffer.clear()
	output_buffer.clear()
	is_processing = false

# --- ITEM INPUT FILTERING ---
func _is_item_valid_for_recipe(item_id: String) -> bool:
	if selected_recipe == "" or not recipe_requirements.has(selected_recipe):
		return false
	var reqs = recipe_requirements[selected_recipe]
	return reqs.has(item_id)

func _on_item_entered(area: Area2D) -> void:
	if not is_placed or area.is_queued_for_deletion():
		return
		
	if input_buffer.size() >= max_storage:
		return
		
	if area.is_in_group("items") and "item_id" in area:
		var incoming_item = area.item_id
		if _is_item_valid_for_recipe(incoming_item):
			input_buffer.append(incoming_item)
			area.queue_free()

func _check_for_waiting_items() -> void:
	for area in input_area.get_overlapping_areas():
		if area.is_queued_for_deletion(): continue
		if input_buffer.size() >= max_storage: break
			
		if area.is_in_group("items") and "item_id" in area:
			var incoming_item = area.item_id
			if _is_item_valid_for_recipe(incoming_item):
				input_buffer.append(incoming_item)
				area.queue_free()

# --- PROCESSING LOGIC ---
func _try_start_processing() -> void:
	if is_processing or selected_recipe == "" or input_buffer.is_empty():
		return
		
	if not recipes.has(selected_recipe) or not recipe_requirements.has(selected_recipe):
		return
		
	var reqs: Dictionary = recipe_requirements[selected_recipe]
	var required_item_id = reqs.keys()[0] if reqs.size() > 0 else ""
	var required_amount: int = reqs.get(required_item_id, 1)
	
	if input_buffer.count(required_item_id) >= required_amount:
		for i in range(required_amount):
			input_buffer.erase(required_item_id)
			
		current_output_scene = recipes[selected_recipe]
		is_processing = true
		
		# Look up duration in recipe_times, fallback to default processing_time if missing
		var craft_duration: float = recipe_times.get(selected_recipe, processing_time)
		processing_timer.wait_time = craft_duration
		processing_timer.start()

func _on_processing_finished() -> void:
	is_processing = false
	if current_output_scene:
		output_buffer.append(current_output_scene)
		current_output_scene = null

func _try_empty_output_buffer() -> void:
	if output_buffer.is_empty() or is_output_blocked():
		return
		
	var output_scene = output_buffer.pop_front()
	var new_item = output_scene.instantiate()
	new_item.global_position = output_marker.global_position
	get_parent().add_child(new_item)
	
	if "item_id" in new_item and get_node_or_null("/root/TutorialManager"):
		TutorialManager.notify_item_produced(new_item.item_id)
