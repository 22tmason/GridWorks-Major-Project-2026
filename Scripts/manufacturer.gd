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

# --- ITEM COST ---
@export var building_item_id: String = "manufacturer_mk1"

# --- RECIPE & CONFIG VARIABLES ---
@export var selected_recipe: String = "" # e.g., "electronic_circuit"
@export var processing_time: float = 3.5
@export var max_storage_per_item: int = 10 

# Multi-item Inventory Hopper (Key: Item ID String, Value: Current Count Integer)
var input_inventory: Dictionary = {}
var output_buffer: Array[PackedScene] = []

# --- RECIPE ENGINE ---
@export var recipes: Dictionary = {}             # Key: String ("electronic_circuit"), Value: PackedScene
@export var recipe_requirements: Dictionary = {}    # Key: String ("electronic_circuit"), Value: Dictionary (Ingredients)

@onready var processing_timer: Timer = $ProcessingTimer
@onready var input_area: Area2D = $InputArea
@onready var output_marker: Marker2D = $OutputMarker
@onready var output_check_area: Area2D = $OutputMarker/OutputCheckArea
# --- RECIPE ENGINE ---
@export var recipe_times: Dictionary = {}  

func _ready() -> void:
	processing_timer.one_shot = true
	processing_timer.timeout.connect(_on_processing_finished)
	input_area.area_entered.connect(_on_item_entered)
	
	input_area.input_pickable = true
	input_area.input_event.connect(_on_machine_clicked)
	_update_sprite_visibility()
	
	if not is_placed:
		BuildManager.current_preview = self
		modulate.a = 0.5

func _update_sprite_visibility() -> void:
	if manufacturer_off and glow_sprite:
		glow_sprite.visible = is_processing
		manufacturer_off.visible = not is_processing

func get_occupied_cells(center_cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(-1, 2):
		for y in range(-1, 2):
			cells.append(center_cell + Vector2i(x, y))
	return cells

func _process(_delta: float) -> void:
	
	if is_placed: 
		return
		
	var current_grid_cell = GridManager.world_to_grid(get_global_mouse_position())
	global_position = GridManager.grid_to_world(current_grid_cell)
	
	var cells_to_check = get_occupied_cells(current_grid_cell)
	if GridManager.is_placement_blocked(cells_to_check) or InventoryManager.get_item_count(building_item_id) <= 0:
		modulate = Color(1.0, 0.4, 0.4, 0.8)
	else:
		modulate = Color(1.0, 1.0, 1.0, 0.5)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		attempt_placement()

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

func _on_machine_clicked(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	# GOAL 1: Prevent the UI from opening if the player is currently placing buildings
	if not is_placed or BuildManager.current_preview != null:
		return
		
	if event is InputEventMouseButton and event.pressed:
		
		# GOAL 3: Shift + Click to Copy/Paste Recipes
		if Input.is_key_pressed(KEY_SHIFT):
			if event.button_index == MOUSE_BUTTON_RIGHT:
				# Copy Recipe
				if selected_recipe != "":
					BuildManager.set_meta("copied_recipe", selected_recipe)
			elif event.button_index == MOUSE_BUTTON_LEFT:
				# Paste Recipe
				var copied = BuildManager.get_meta("copied_recipe") if BuildManager.has_meta("copied_recipe") else ""
				if copied != "" and recipes.has(copied):
					set_active_recipe(copied)
			return # Exit early so the UI doesn't open
			
		# Normal Left Click -> Open UI
		if event.button_index == MOUSE_BUTTON_LEFT:
			var ui = get_tree().get_first_node_in_group("machine_ui")
			if ui:
				ui.open_ui(self)

func set_active_recipe(recipe_id: String) -> void:
	selected_recipe = recipe_id
	
	# Optional but recommended: Flush the old inventory so you don't 
	# get copper cables stuck in a machine now trying to build engines!
	input_inventory.clear() 
	output_buffer.clear()
	is_processing = false
	
	# GOAL 2: Display the tiny product icon on the machine sprite
	var recipe_icon = get_node_or_null("RecipeIcon")
	if recipe_icon:
		if recipe_id != "" and InventoryManager.item_database.has(recipe_id):
			var texture_path = InventoryManager.item_database[recipe_id]["texture"]
			recipe_icon.texture = load(texture_path)
			recipe_icon.visible = true
		else:
			recipe_icon.visible = false

func attempt_placement() -> void:
	var inv_ui = get_tree().current_scene.get_node_or_null("InventoryUI")
	var machine_ui = get_tree().get_first_node_in_group("machine_ui")
	
	if (inv_ui and inv_ui.visible) or (machine_ui and machine_ui.visible):
		return
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
		
		# Spawn next preview
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

func _is_output_blocked() -> bool:
	var overlapping = output_check_area.get_overlapping_areas()
	for thing in overlapping:
		if thing.is_in_group("items"):
			return true
	return false

func _on_item_entered(area: Area2D) -> void:
	if not is_placed or area.is_queued_for_deletion():
		return
		
	if area.is_in_group("items") and "item_id" in area:
		var incoming_item = area.item_id
		if _does_recipe_need_item(incoming_item):
			var current_count = input_inventory.get(incoming_item, 0)
			if current_count < max_storage_per_item:
				input_inventory[incoming_item] = current_count + 1
				area.queue_free()

func _does_recipe_need_item(item_id: String) -> bool:
	if selected_recipe == "" or not recipe_requirements.has(selected_recipe):
		return false
	var requirements = recipe_requirements[selected_recipe]
	return requirements.has(item_id)

func _try_start_processing() -> void:
	if is_processing or selected_recipe == "" or not _has_required_ingredients():
		return
		
	var requirements = recipe_requirements[selected_recipe]
	for ingredient in requirements.keys():
		var amount = requirements[ingredient]
		input_inventory[ingredient] -= amount
		
	is_processing = true
	
	# Look up duration in recipe_times, fallback to default processing_time if missing
	var craft_duration: float = recipe_times.get(selected_recipe, processing_time)
	processing_timer.wait_time = craft_duration
	processing_timer.start()
	

func _has_required_ingredients() -> bool:
	if not recipe_requirements.has(selected_recipe):
		return false
		
	var requirements = recipe_requirements[selected_recipe]
	for ingredient in requirements.keys():
		var needed = requirements[ingredient]
		var owned = input_inventory.get(ingredient, 0)
		if owned < needed:
			return false
	return true

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
	
	if "item_id" in new_item and get_node_or_null("/root/TutorialManager"):
		TutorialManager.notify_item_produced(new_item.item_id)
		StatisticsManager.log_production(new_item.item_id, 1)

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
