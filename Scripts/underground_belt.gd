extends Node2D

# --- MATCHING STRAIGHT BELT VARIABLES ---
enum Direction { UP, RIGHT, DOWN, LEFT }
@export var current_direction: Direction = Direction.RIGHT
var is_placed := false
@export var speed: float = 128.0
var push_direction: Vector2 = Vector2.RIGHT
@export var lane_offset: float = 16.0 

# --- UNDERGROUND NODES ---
@onready var entrance_sprite: AnimatedSprite2D = $EntranceSprite
@onready var exit_sprite: AnimatedSprite2D = $ExitSprite
@onready var area: Area2D = $Area2D

# --- UNDERGROUND LOGIC ---
var linked_partner: Node2D = null
var ejecting_items: Array = []

@export var is_entrance: bool = true:
	set(value):
		is_entrance = value
		_update_visuals()

func _ready() -> void:
	_update_visuals()
	
	if not is_placed:
		BuildManager.current_preview = self
		modulate.a = 0.5
	else:
		area.area_entered.connect(_on_area_entered)

func _update_visuals() -> void:
	if not is_inside_tree(): return 
	
	entrance_sprite.visible = is_entrance
	exit_sprite.visible = not is_entrance

# --- NEW: 1x1 Building footprint ---
func get_occupied_cells(center_cell: Vector2i) -> Array[Vector2i]:
	return [center_cell]

func _process(_delta: float) -> void:
	if is_placed:
		return
		
	var mouse_pos = get_global_mouse_position()
	var current_grid_cell = GridManager.world_to_grid(mouse_pos)
	var snapped_position = GridManager.grid_to_world(current_grid_cell)
	
	# --- THE FIX: Axis Locking, Forward Forcing, AND Max Distance ---
	if not is_entrance and is_instance_valid(linked_partner):
		var entrance_pos = linked_partner.global_position
		
		# Assuming your grid tiles are 64x64.
		var min_distance = 64.0  # Minimum 1 block away
		var max_distance = 320.0 # Maximum 5 blocks away (5 * 64)
		
		match current_direction:
			Direction.UP:
				snapped_position.y = entrance_pos.y
				# In Godot, UP is negative Y. 
				# Clamp between (Entrance - 384) and (Entrance - 64)
				snapped_position.x = clamp(snapped_position.x, entrance_pos.x - max_distance, entrance_pos.x - min_distance)
				
			Direction.DOWN:
				snapped_position.y = entrance_pos.y
				# In Godot, DOWN is positive Y.
				# Clamp between (Entrance + 64) and (Entrance + 384)
				snapped_position.x = clamp(snapped_position.x, entrance_pos.x + min_distance, entrance_pos.x + max_distance)
				
			Direction.LEFT:
				snapped_position.x = entrance_pos.x
				# In Godot, LEFT is negative X.
				# Clamp between (Entrance - 384) and (Entrance - 64)
				snapped_position.y = clamp(snapped_position.y, entrance_pos.y - max_distance, entrance_pos.y - min_distance)
				
			Direction.RIGHT:
				snapped_position.x = entrance_pos.x
				# In Godot, RIGHT is positive X.
				# Clamp between (Entrance + 64) and (Entrance + 384)
				snapped_position.y = clamp(snapped_position.y, entrance_pos.y + min_distance, entrance_pos.y + max_distance)
				
	global_position = snapped_position

	# --- NEW: Universal Red/White Overlay Check ---
	# We use the position AFTER clamping so the red/white colors match where the belt actually is
	var actual_grid_cell = GridManager.world_to_grid(global_position)
	var cells_to_check = get_occupied_cells(actual_grid_cell)
	
	if GridManager.is_placement_blocked(cells_to_check):
		modulate = Color(1.0, 0.4, 0.4, 0.8) # Red if blocked
	else:
		modulate = Color(1.0, 1.0, 1.0, 0.5) # White if clear

func _unhandled_input(event: InputEvent) -> void:
	if is_placed: return
		
	# --- NEW: Rotate belt matching your straight belt logic ---
	if event is InputEventKey and event.keycode == KEY_R and event.pressed:
		rotate_belt()
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Use the current global_position instead of the mouse to respect the clamping!
		var actual_cell = GridManager.world_to_grid(global_position)
		
		# --- UPDATED: Pass the ARRAY of cells to the GridManager! ---
		var cells_to_claim = get_occupied_cells(actual_cell)
		
		if GridManager.place_item(cells_to_claim, self):
			is_placed = true
			modulate = Color(1.0, 1.0, 1.0, 1.0) # Reset fully back to normal color
			area.area_entered.connect(_on_area_entered)
			
			# If Entrance placed -> Spawn Exit Preview
			if is_entrance:
				var exit_preview = load(scene_file_path).instantiate()
				exit_preview.is_entrance = false 
				exit_preview.current_direction = current_direction
				exit_preview.rotation_degrees = rotation_degrees
				exit_preview.linked_partner = self 
				get_parent().add_child(exit_preview)
				
			# If Exit placed -> Finish link and spawn NEW Entrance Preview
			else:
				if linked_partner != null:
					linked_partner.linked_partner = self 
				
				var next_entrance = load(scene_file_path).instantiate()
				next_entrance.is_entrance = true
				next_entrance.current_direction = current_direction
				next_entrance.rotation_degrees = rotation_degrees
				get_parent().add_child(next_entrance)

func rotate_belt() -> void:
	current_direction = (current_direction + 1) % 4 as Direction
	rotation_degrees += 90

# --- ITEM HANDLING ---
func _on_area_entered(hit_area: Area2D) -> void:
	if not is_entrance: return 
	
	if hit_area.is_in_group("items") and is_instance_valid(linked_partner):
		hit_area.set_physics_process(false)
		hit_area.visible = false
		
		# 1. Figure out which way the belt is facing
		var forward_dir = push_direction.rotated(global_rotation).round()
		# 2. Get the cross-axis (the line cutting left-to-right across the belt)
		var sideways_dir = Vector2(-forward_dir.y, forward_dir.x) 
		
		# --- FIXED: Renamed to saved_lane_offset to prevent shadowing ---
		var saved_lane_offset = (hit_area.global_position - global_position).project(sideways_dir)
		
		# Send to the void so it doesn't block traffic
		hit_area.global_position = Vector2(-99999, -99999)
		
		var distance = global_position.distance_to(linked_partner.global_position)
		var travel_time = distance / speed 
		
		var timer = get_tree().create_timer(travel_time)
		timer.timeout.connect(_on_item_arrived.bind(hit_area, saved_lane_offset))

# --- FIXED: Parameter renamed to saved_lane_offset ---
func _on_item_arrived(item: Area2D, saved_lane_offset: Vector2) -> void:
	if is_instance_valid(item) and is_instance_valid(linked_partner):
		
		# Teleport to the exit's center PLUS the saved lane offset!
		item.global_position = linked_partner.global_position + saved_lane_offset
		item.visible = true
		
		if not linked_partner.ejecting_items.has(item):
			linked_partner.ejecting_items.append(item)

# --- EXACT STRAIGHT BELT PUSH LOGIC ---
func _physics_process(delta: float) -> void:
	if not is_placed: return
	
	if not is_entrance:
		var world_dir = push_direction.rotated(global_rotation).round()
		
		for item in ejecting_items.duplicate():
			if is_instance_valid(item):
				item.global_position += world_dir * speed * delta
				
				var offset_vector = item.global_position - global_position
				var distance_forward = offset_vector.dot(world_dir)
				
				if distance_forward >= 32.0:
					item.set_physics_process(true)
					ejecting_items.erase(item)
			else:
				ejecting_items.erase(item)
