extends Node2D

# --- SPRITE REFERENCES ---
@onready var furnace_off: Sprite2D = $FurnaceOff
@onready var glow_sprite: Sprite2D = $GlowSprite

# --- UPDATE THIS VARIABLE ---
var is_smelting := false:
	set(value):
		is_smelting = value
		_update_sprite_visibility()
			
# --- BUILDING SYSTEM VARIABLES ---
enum Direction { UP, RIGHT, DOWN, LEFT }
@export var current_direction: Direction = Direction.DOWN
var is_placed := false

# --- NEW: Identify what item this building costs ---
@export var building_item_id: String = "stone_furnace"

# --- RECIPE & STORAGE VARIABLES ---
@export var smelting_time: float = 3.0 
@export var max_storage: int = 5 

var input_buffer: Array[String] = []
var output_buffer: Array[PackedScene] = []

@export var recipes: Dictionary = {} 

@onready var smelting_timer: Timer = $SmeltingTimer
@onready var input_area: Area2D = $InputArea
@onready var output_marker: Marker2D = $OutputMarker
@onready var output_check_area: Area2D = $OutputMarker/OutputCheckArea

var current_output_scene: PackedScene = null 

func _ready() -> void:
	smelting_timer.one_shot = true
	smelting_timer.timeout.connect(_on_smelting_finished)
	input_area.area_entered.connect(_on_item_entered)
	
	_update_sprite_visibility()
	
	if not is_placed:
		BuildManager.current_preview = self
		modulate.a = 0.5

func _update_sprite_visibility() -> void:
	if furnace_off and glow_sprite:
		glow_sprite.visible = is_smelting
		furnace_off.visible = not is_smelting

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
	
	# --- UPDATED: GridManager checks if the physical space is clear AND if inventory has stock ---
	if GridManager.is_placement_blocked(cells_to_check, building_item_id):
		modulate = Color(1.0, 0.4, 0.4, 0.8) 
	else:
		modulate = Color(1.0, 1.0, 1.0, 0.5) 

func _unhandled_input(event: InputEvent) -> void:
	if is_placed:
		return
		
	if event is InputEventKey and event.keycode == KEY_R and event.pressed:
		rotate_furnace()
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var current_grid_cell = GridManager.world_to_grid(get_global_mouse_position())
		var cells_to_claim = get_occupied_cells(current_grid_cell)
		
		# --- UPDATED: GridManager handles checking the inventory AND deducting the item! ---
		var success = GridManager.place_item(cells_to_claim, self)
		if success:
			is_placed = true
			modulate = Color(1.0, 1.0, 1.0, 1.0)
			
			# Check for any items stranded directly underneath us upon placement
			_check_for_waiting_items()
			
			var next_furnace = load(scene_file_path).instantiate()
			next_furnace.current_direction = current_direction
			next_furnace.rotation_degrees = rotation_degrees
			get_parent().add_child(next_furnace)

func rotate_furnace() -> void:
	current_direction = (current_direction + 1) % 4 as Direction
	rotation_degrees += 90

func _on_item_entered(area: Area2D) -> void:
	if not is_placed: return
	
	if area.is_in_group("items") and "item_id" in area:
		var incoming_ore = area.item_id
		
		if recipes.has(incoming_ore):
			if input_buffer.size() < max_storage:
				input_buffer.append(incoming_ore)
				area.queue_free() 
				print("Furnace buffered raw input: ", incoming_ore, " (Buffer: ", input_buffer.size(), "/", max_storage, ")")
			else:
				print("Furnace input hopper is FULL!")
		else:
			if not incoming_ore.ends_with("_ingot"):
				print("Furnace rejected item: No recipe for ", incoming_ore)

func _physics_process(_delta: float) -> void:
	if not is_placed: 
		return
		
	_try_empty_output_buffer()
	
	if not is_smelting and not input_buffer.is_empty() and output_buffer.size() < max_storage:
		_start_smelting_next_item()
		
	if input_buffer.size() < max_storage:
		_check_for_waiting_items()

func _start_smelting_next_item() -> void:
	var next_ore = input_buffer.pop_front()
	current_output_scene = recipes[next_ore]
	
	is_smelting = true
	smelting_timer.wait_time = smelting_time
	smelting_timer.start()
	print("Started smelting buffered item: ", next_ore)

func _on_smelting_finished() -> void:
	is_smelting = false
	if current_output_scene:
		output_buffer.append(current_output_scene)
		current_output_scene = null
		print("Smelting complete! Item added to output tray. (Tray: ", output_buffer.size(), ")")

func _try_empty_output_buffer() -> void:
	if output_buffer.is_empty():
		return
		
	if is_output_blocked():
		return 
		
	var ingot_scene = output_buffer.pop_front()
	var new_item = ingot_scene.instantiate()
	new_item.global_position = output_marker.global_position
	get_parent().add_child(new_item)
	
	# --- NOTIFY TUTORIAL OF ITEM PRODUCTION ---
	if "item_id" in new_item and get_node_or_null("/root/TutorialManager"):
		TutorialManager.notify_item_produced(new_item.item_id)
		
	print("Furnace dispatched item from tray!")

func _check_for_waiting_items() -> void:
	for area in input_area.get_overlapping_areas():
		if area.is_queued_for_deletion(): continue # Safely ignore items already grabbed
		
		if input_buffer.size() >= max_storage:
			break
			
		if area.is_in_group("items") and "item_id" in area:
			var incoming_ore = area.item_id
			if recipes.has(incoming_ore):
				input_buffer.append(incoming_ore)
				area.queue_free()
				print("Furnace slurped waiting item: ", incoming_ore)

func is_output_blocked() -> bool:
	var overlapping_things = output_check_area.get_overlapping_areas()
	for thing in overlapping_things:
		if thing.is_in_group("items"):
			if "item_id" in thing:
				if recipes.has(thing.item_id):
					continue
				return true
	return false
