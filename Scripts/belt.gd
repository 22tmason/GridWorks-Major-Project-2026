extends Area2D

enum Direction { UP, RIGHT, DOWN, LEFT }

@export var current_direction: Direction = Direction.DOWN 
var is_placed := false
@export var speed: float = 128.0
var push_direction: Vector2 = Vector2.DOWN 
@export var lane_offset: float = 16.0 

# --- NEW: Identify what item this building costs ---
@export var building_item_id: String = "" 

func _ready() -> void:
	if not is_placed:
		BuildManager.current_preview = self
		modulate.a = 0.5
		
	# --- THE FIX: Force the new belt to sync with the rest of the factory ---
	sync_animation_with_existing_belts()

# Scans the grid for an existing belt and copies its animation frame
# Scans the grid for an existing belt and copies its animation frame
func sync_animation_with_existing_belts() -> void:
	var my_sprite = get_node_or_null("AnimatedSprite2D")
	if my_sprite == null:
		return
		
	# Loop through all buildings currently placed in the world
	for cell in GridManager.grid_data:
		var building = GridManager.grid_data[cell]
		
		# THE FIX: Ensure the building is actually alive and not in the process of being deleted!
		if is_instance_valid(building) and not building.is_queued_for_deletion():
			if "building_item_id" in building and building.building_item_id == building_item_id:
				var other_sprite = building.get_node_or_null("AnimatedSprite2D")
				
				if other_sprite != null:
					# Copy the exact frame and progress of the older belt
					my_sprite.set_frame_and_progress(other_sprite.frame, other_sprite.frame_progress)
					
					# We only need to sync with ONE belt, so we can stop looking!
					return

func get_occupied_cells(center_cell: Vector2i) -> Array[Vector2i]:
	return [center_cell]

func _process(_delta: float) -> void:
	if is_placed:
		return
		
	var current_grid_cell = GridManager.world_to_grid(get_global_mouse_position())
	global_position = GridManager.grid_to_world(current_grid_cell)

	var cells_to_check = get_occupied_cells(current_grid_cell)
	
	# --- NEW: Check if placement is blocked OR inventory is empty ---
	if GridManager.is_placement_blocked(cells_to_check) or InventoryManager.get_item_count(building_item_id) <= 0:
		modulate = Color(1.0, 0.4, 0.4, 0.8) # Red if blocked or out of stock
	else:
		modulate = Color(1.0, 1.0, 1.0, 0.5) # White if clear and in stock
	# Continuous placement check (Supports holding left-click while moving with WASD)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		attempt_placement()

func _unhandled_input(event: InputEvent) -> void:
	if is_placed:
		return
		
	if event is InputEventKey and event.keycode == KEY_R and event.pressed:
		rotate_belt()
		
	# 1. Handle the initial single click
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		attempt_placement()
		
	# 2. Handle the click-and-drag 
	# (Triggers when the mouse moves AND the left button is actively held down)
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		attempt_placement()

# Extracted logic so both clicking and dragging can use it
func attempt_placement() -> void:
	var inv_ui = get_tree().current_scene.get_node_or_null("InventoryUI")
	var machine_ui = get_tree().get_first_node_in_group("machine_ui")
	
	if (inv_ui and inv_ui.visible) or (machine_ui and machine_ui.visible):
		return

	# Block placement if we don't have the item
	if InventoryManager.get_item_count(building_item_id) <= 0:
		return 
		
	var current_grid_cell = GridManager.world_to_grid(get_global_mouse_position())
	var cells_to_claim = get_occupied_cells(current_grid_cell)
	
	# Early exit: Prevent the code from constantly trying to place on an already occupied cell while dragging
	if GridManager.is_placement_blocked(cells_to_claim):
		return
		
	var success = GridManager.place_item(cells_to_claim, self)
	
	if success:
		# --- THE FIX: Force the visual position to snap to the target cell! ---
		global_position = GridManager.grid_to_world(current_grid_cell)
		
		# Consume the item upon successful placement
		is_placed = true
		modulate = Color(1.0, 1.0, 1.0, 1.0) 
		
		# ALWAYS spawn the next preview
		var next_belt = BuildManager.selected_scene.instantiate()
		get_parent().add_child(next_belt)
		
		var current_sprite = get_node_or_null("AnimatedSprite2D")
		var next_sprite = next_belt.get_node_or_null("AnimatedSprite2D")
		
		if current_sprite != null and next_sprite != null:
			next_sprite.set_frame_and_progress(current_sprite.frame, current_sprite.frame_progress)
		
		next_belt.rotation_degrees = rotation_degrees
		if "current_direction" in next_belt: 
			next_belt.current_direction = current_direction

func rotate_belt() -> void:
	current_direction = (current_direction + 1) % 4 as Direction
	rotation_degrees += 90
