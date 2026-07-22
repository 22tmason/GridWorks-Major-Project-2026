extends Node2D

# --- SPRITE REFERENCES ---
@onready var manufacturer_off: Sprite2D = $ManufacturerOff
@onready var glow_sprite: Sprite2D = $GlowSprite

# --- STATE VARIABLES ---
var is_processing := false:
	set(value):
		is_processing = value
		_update_sprite_visibility()
		
enum Direction { UP, RIGHT, DOWN, LEFT }
@export var current_direction: Direction = Direction.DOWN
var is_placed := false

# --- NEW: Identify what item this building costs ---
@export var building_item_id: String = "manufacturer_mk1"

# --- RECIPE & CONFIG VARIABLES ---
@export var selected_recipe: String = "" # e.g., "electronic_circuit"
@export var processing_time: float = 3.5
@export var max_storage_per_item: int = 10 

# Multi-item Inventory Hopper (Key: Item ID String, Value: Current Count Integer)
var input_inventory: Dictionary = {}
var output_buffer: Array[PackedScene] = []

# --- THE ADVANCED RECIPE ENGINE ---
@export var recipes: Dictionary = {}             # Key: String ("electronic_circuit"), Value: PackedScene
@export var recipe_requirements: Dictionary = {}    # Key: String ("electronic_circuit"), Value: Dictionary (Ingredients)

@onready var processing_timer: Timer = $ProcessingTimer
@onready var input_area: Area2D = $InputArea
@onready var output_marker: Marker2D = $OutputMarker
@onready var output_check_area: Area2D = $OutputMarker/OutputCheckArea

func _ready() -> void:
	processing_timer.one_shot = true
	processing_timer.timeout.connect(_on_processing_finished)
	input_area.area_entered.connect(_on_item_entered)
	
	_update_sprite_visibility()
	
	if not is_placed:
		BuildManager.current_preview = self
		modulate.a = 0.5

func _update_sprite_visibility() -> void:
	if manufacturer_off and glow_sprite:
		glow_sprite.visible = is_processing
		manufacturer_off.visible = not is_processing

func get_occupied_cells(center_cell: Vector2i) -> Array[Vector2i]:
	# Manufacturers are usually massive! Setting this to a 3x3 footprint.
	# Modify this grid layout if your sprite is smaller/larger.
	var cells: Array[Vector2i] = []
	for x in range(-1, 2):
		for y in range(-1, 2):
			cells.append(center_cell + Vector2i(x, y))
	return cells

func _process(_delta: float) -> void:
	if is_placed: return
		
	var current_grid_cell = GridManager.world_to_grid(get_global_mouse_position())
	global_position = GridManager.grid_to_world(current_grid_cell)
	
	var cells_to_check = get_occupied_cells(current_grid_cell)
	
	# --- UPDATED: GridManager checks physical space AND inventory stock ---
	if GridManager.is_placement_blocked(cells_to_check, building_item_id):
		modulate = Color(1.0, 0.4, 0.4, 0.8) 
	else:
		modulate = Color(1.0, 1.0, 1.0, 0.5) 

func _unhandled_input(event: InputEvent) -> void:
	if is_placed: return
		
	if event is InputEventKey and event.keycode == KEY_R and event.pressed:
		current_direction = (current_direction + 1) % 4 as Direction
		rotation_degrees += 90
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var current_grid_cell = GridManager.world_to_grid(get_global_mouse_position())
		var cells_to_claim = get_occupied_cells(current_grid_cell)
		
		# --- UPDATED: GridManager automatically deducts the item upon successful placement! ---
		var success = GridManager.place_item(cells_to_claim, self)
		if success:
			is_placed = true
			modulate = Color(1.0, 1.0, 1.0, 1.0)
			_check_for_stranded_items()
			
			var next_machine = load(scene_file_path).instantiate()
			next_machine.current_direction = current_direction
			next_machine.rotation_degrees = rotation_degrees
			get_parent().add_child(next_machine)

func _check_for_stranded_items() -> void:
	for area in input_area.get_overlapping_areas():
		_on_item_entered(area)

# --- MANUFACTURER CORE LOGIC ---

func _on_item_entered(area: Area2D) -> void:
	if not is_placed or area.is_queued_for_deletion(): return
	
	if area.is_in_group("items") and "item_id" in area:
		var incoming_item = area.item_id
		
		if _does_recipe_need_item(incoming_item):
			var current_count = input_inventory.get(incoming_item, 0)
			
			if current_count < max_storage_per_item:
				input_inventory[incoming_item] = current_count + 1
				area.queue_free()
				print("Manufacturer accepted: ", incoming_item, " (", input_inventory[incoming_item], "/", max_storage_per_item, ")")

func _physics_process(_delta: float) -> void:
	if not is_placed: return
		
	# 1. Output finished items
	_try_empty_output_buffer()
	
	# 2. Check if we have enough materials to start a craft cycle
	if not is_processing and output_buffer.size() < 5:
		if _has_all_required_materials():
			_start_manufacturing()
			
	# 3. Constantly pull items waiting in the input zone
	_check_for_waiting_items()

func _does_recipe_need_item(item_id: String) -> bool:
	if not recipe_requirements.has(selected_recipe): return false
	var requirements: Dictionary = recipe_requirements[selected_recipe]
	return requirements.has(item_id)

func _has_all_required_materials() -> bool:
	if selected_recipe == "" or not recipe_requirements.has(selected_recipe): 
		return false
		
	var requirements: Dictionary = recipe_requirements[selected_recipe]
	
	for ingredient in requirements.keys():
		var required_amount = requirements[ingredient]
		var current_stock = input_inventory.get(ingredient, 0)
		
		if current_stock < required_amount:
			return false # Missing ingredients!
			
	return true

func _start_manufacturing() -> void:
	var requirements: Dictionary = recipe_requirements[selected_recipe]
	
	# Deduct materials from internal inventory
	for ingredient in requirements.keys():
		input_inventory[ingredient] -= requirements[ingredient]
		
	is_processing = true
	processing_timer.wait_time = processing_time
	processing_timer.start()
	print("Manufacturer started crafting: ", selected_recipe)

func _on_processing_finished() -> void:
	is_processing = false
	var product_scene = recipes.get(selected_recipe)
	if product_scene:
		output_buffer.append(product_scene)

func _try_empty_output_buffer() -> void:
	if output_buffer.is_empty() or _is_output_blocked(): 
		return
		
	var product_scene = output_buffer.pop_front()
	var new_item = product_scene.instantiate()
	new_item.global_position = output_marker.global_position
	get_parent().add_child(new_item)
	
	# --- NOTIFY TUTORIAL OF ITEM PRODUCTION ---
	if "item_id" in new_item and get_node_or_null("/root/TutorialManager"):
		TutorialManager.notify_item_produced(new_item.item_id)

func _check_for_waiting_items() -> void:
	for area in input_area.get_overlapping_areas():
		if area.is_queued_for_deletion(): continue
		if area.is_in_group("items") and "item_id" in area:
			var incoming_item = area.item_id
			if _does_recipe_need_item(incoming_item):
				var current_count = input_inventory.get(incoming_item, 0)
				if current_count < max_storage_per_item:
					input_inventory[incoming_item] = current_count + 1
					area.queue_free()

func _is_output_blocked() -> bool:
	for thing in output_marker.get_node("OutputCheckArea").get_overlapping_areas():
		if thing.is_in_group("items"):
			return true
	return false
