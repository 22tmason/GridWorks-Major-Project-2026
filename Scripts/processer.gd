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

# --- RECIPE & STORAGE VARIABLES ---
@export var processing_time: float = 2.0 
@export var max_storage: int = 10 # Slightly higher buffer since it eats items fast!

# Internal hoppers
var input_buffer: Array[String] = []
var output_buffer: Array[PackedScene] = []

# --- THE RECIPE ENGINE ---
@export var recipes: Dictionary = {}       # Key: String ("iron_ingot"), Value: PackedScene (iron_gear.tscn)
@export var recipe_costs: Dictionary = {}  # Key: String ("iron_ingot"), Value: int (2)

@onready var processing_timer: Timer = $ProcessingTimer
@onready var input_area: Area2D = $InputArea
@onready var output_marker: Marker2D = $OutputMarker
@onready var output_check_area: Area2D = $OutputMarker/OutputCheckArea

var current_output_scene: PackedScene = null 

func _ready() -> void:
	processing_timer.one_shot = true
	processing_timer.timeout.connect(_on_processing_finished)
	input_area.area_entered.connect(_on_item_entered)
	
	_update_sprite_visibility()
	
	if not is_placed:
		BuildManager.current_preview = self
		modulate.a = 0.5

func _update_sprite_visibility() -> void:
	if processor_off and glow_sprite:
		glow_sprite.visible = is_processing
		processor_off.visible = not is_processing

func get_occupied_cells(center_cell: Vector2i) -> Array[Vector2i]:
	# Assumes 2x2 size like the furnace. Change if your processor is 1x1!
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
	
	if GridManager.is_placement_blocked(cells_to_check):
		modulate = Color(1.0, 0.4, 0.4, 0.8) 
	else:
		modulate = Color(1.0, 1.0, 1.0, 0.5) 

func _unhandled_input(event: InputEvent) -> void:
	if is_placed:
		return
		
	if event is InputEventKey and event.keycode == KEY_R and event.pressed:
		rotate_processor()
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var current_grid_cell = GridManager.world_to_grid(get_global_mouse_position())
		var cells_to_claim = get_occupied_cells(current_grid_cell)
		
		var success = GridManager.place_item(cells_to_claim, self)
		if success:
			is_placed = true
			modulate = Color(1.0, 1.0, 1.0, 1.0)
			pickup_area_connected_safely()
			
			var next_processor = load(scene_file_path).instantiate()
			next_processor.current_direction = current_direction
			next_processor.rotation_degrees = rotation_degrees
			get_parent().add_child(next_processor)

func rotate_processor() -> void:
	current_direction = (current_direction + 1) % 4 as Direction
	rotation_degrees += 90

func pickup_area_connected_safely() -> void:
	# Checks for items already resting inside our zone when placed
	for area in input_area.get_overlapping_areas():
		_on_item_entered(area)

# --- PROCESSING ENGINE LOGIC ---

func _on_item_entered(area: Area2D) -> void:
	if not is_placed: return
	# --- FIX: Ignore items already marked for deletion ---
	if area.is_queued_for_deletion(): return 
	
	if area.is_in_group("items") and "item_id" in area:
		var incoming_item = area.item_id
		
		if recipes.has(incoming_item):
			if input_buffer.size() < max_storage:
				input_buffer.append(incoming_item)
				area.queue_free() 
			else:
				print("Processor input hopper full!")

func _physics_process(_delta: float) -> void:
	if not is_placed: 
		return
		
	# 1. Clear the output tray if possible
	_try_empty_output_buffer()
	
	# 2. Check if we can craft something new
	if not is_processing and not input_buffer.is_empty() and output_buffer.size() < max_storage:
		var next_recipe_input = input_buffer[0]
		var required_cost = recipe_costs.get(next_recipe_input, 1) # Defaults to 1 if not set
		
		# Count if we have enough matching items in our buffer
		if input_buffer.count(next_recipe_input) >= required_cost:
			_start_processing_recipe(next_recipe_input, required_cost)
			
	# 3. Pull in items that are waiting outside on the belt
	if input_buffer.size() < max_storage:
		_check_for_waiting_items()

func _start_processing_recipe(item_id: String, cost: int) -> void:
	# Delete the exact number of ingredients from our buffer array
	for i in range(cost):
		input_buffer.erase(item_id)
		
	current_output_scene = recipes[item_id]
	
	is_processing = true
	processing_timer.wait_time = processing_time
	processing_timer.start()
	print("Processor consuming ", cost, "x ", item_id, " to make a gear!")

func _on_processing_finished() -> void:
	is_processing = false
	if current_output_scene:
		output_buffer.append(current_output_scene)
		current_output_scene = null

func _try_empty_output_buffer() -> void:
	if output_buffer.is_empty() or is_output_blocked():
		return
		
	var product_scene = output_buffer.pop_front()
	var new_item = product_scene.instantiate()
	new_item.global_position = output_marker.global_position
	get_parent().add_child(new_item)

func _check_for_waiting_items() -> void:
	for area in input_area.get_overlapping_areas():
		# --- FIX: Skip items already marked for deletion ---
		if area.is_queued_for_deletion(): continue 
		
		if input_buffer.size() >= max_storage:
			break
			
		if area.is_in_group("items") and "item_id" in area:
			var incoming_item = area.item_id
			if recipes.has(incoming_item):
				input_buffer.append(incoming_item)
				area.queue_free()

func is_output_blocked() -> bool:
	var overlapping_things = output_check_area.get_overlapping_areas()
	for thing in overlapping_things:
		if thing.is_in_group("items") and "item_id" in thing:
			# Ignore raw materials passing through or waiting to get processed
			if recipes.has(thing.item_id):
				continue
			return true
	return false
