extends Node2D

# --- MATCHING STRAIGHT BELT VARIABLES ---
enum Direction { UP, RIGHT, DOWN, LEFT }
@export var current_direction: Direction = Direction.RIGHT # <--- Set to RIGHT
var is_placed := false
@export var speed: float = 128.0
var push_direction: Vector2 = Vector2.RIGHT # <--- Set to RIGHT
@export var lane_offset: float = 16.0

@export var building_item_id: String = "underground_belt"

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
	
	if entrance_sprite and exit_sprite: 
		entrance_sprite.visible = is_entrance
		exit_sprite.visible = not is_entrance

func get_occupied_cells(center_cell: Vector2i) -> Array[Vector2i]:
	return [center_cell]

func _process(delta: float) -> void:
	if is_placed:
		return
		
	var mouse_pos = get_global_mouse_position()
	var current_grid_cell = GridManager.world_to_grid(mouse_pos)
	var snapped_position = GridManager.grid_to_world(current_grid_cell)
	
	# --- Axis Locking, Forward Forcing, AND Max Distance ---
	if is_instance_valid(linked_partner):
		var anchor_pos = linked_partner.global_position
		var min_dist = 64.0
		var max_dist = 320.0
		var axis_diff = 0.0
		
		match current_direction:
			Direction.RIGHT: # Flow is Horizontal (Left to Right)
				snapped_position.y = anchor_pos.y
				axis_diff = snapped_position.x - anchor_pos.x
				if axis_diff >= 0: 
					snapped_position.x = clamp(snapped_position.x, anchor_pos.x + min_dist, anchor_pos.x + max_dist)
					is_entrance = false
					linked_partner.is_entrance = true
				else: 
					snapped_position.x = clamp(snapped_position.x, anchor_pos.x - max_dist, anchor_pos.x - min_dist)
					is_entrance = true
					linked_partner.is_entrance = false
					
			Direction.LEFT: # Flow is Horizontal (Right to Left)
				snapped_position.y = anchor_pos.y
				axis_diff = snapped_position.x - anchor_pos.x
				if axis_diff <= 0: 
					snapped_position.x = clamp(snapped_position.x, anchor_pos.x - max_dist, anchor_pos.x - min_dist)
					is_entrance = false
					linked_partner.is_entrance = true
				else: 
					snapped_position.x = clamp(snapped_position.x, anchor_pos.x + min_dist, anchor_pos.x + max_dist)
					is_entrance = true
					linked_partner.is_entrance = false

			Direction.DOWN: # Flow is Vertical (Top to Bottom)
				snapped_position.x = anchor_pos.x
				axis_diff = snapped_position.y - anchor_pos.y
				if axis_diff >= 0: 
					snapped_position.y = clamp(snapped_position.y, anchor_pos.y + min_dist, anchor_pos.y + max_dist)
					is_entrance = false
					linked_partner.is_entrance = true
				else: 
					snapped_position.y = clamp(snapped_position.y, anchor_pos.y - max_dist, anchor_pos.y - min_dist)
					is_entrance = true
					linked_partner.is_entrance = false
					
			Direction.UP: # Flow is Vertical (Bottom to Top)
				snapped_position.x = anchor_pos.x
				axis_diff = snapped_position.y - anchor_pos.y
				if axis_diff <= 0: 
					snapped_position.y = clamp(snapped_position.y, anchor_pos.y - max_dist, anchor_pos.y - min_dist)
					is_entrance = false
					linked_partner.is_entrance = true
				else: 
					snapped_position.y = clamp(snapped_position.y, anchor_pos.y + min_dist, anchor_pos.y + max_dist)
					is_entrance = true
					linked_partner.is_entrance = false
					
	global_position = snapped_position

	var actual_grid_cell = GridManager.world_to_grid(global_position)
	var cells_to_check = get_occupied_cells(actual_grid_cell)
	
	if GridManager.is_placement_blocked(cells_to_check, building_item_id):
		modulate = Color(1.0, 0.4, 0.4, 0.8) 
	else:
		modulate = Color(1.0, 1.0, 1.0, 0.5) 
		
	# REMOVED: The Continuous WASD check block was deleted from here!

func _unhandled_input(event: InputEvent) -> void:
	if is_placed: return
		
	if event is InputEventKey and event.keycode == KEY_R and event.pressed:
		rotate_belt()
		
	# ALLOW ONLY: Discrete clicks (so the exit doesn't instantly drop on the same click)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		attempt_placement()

# --- EXTRACTED PLACEMENT LOGIC ---
func attempt_placement() -> void:
	# Prevent building while menus are open
	var inv_ui = get_tree().current_scene.get_node_or_null("InventoryUI")
	var machine_ui = get_tree().get_first_node_in_group("machine_ui")
	if (inv_ui and inv_ui.visible) or (machine_ui and machine_ui.visible):
		return

	if InventoryManager.get_item_count(building_item_id) <= 0:
		return

	var actual_cell = GridManager.world_to_grid(global_position)
	var cells_to_claim = get_occupied_cells(actual_cell)
	
	# Block placement if invalid
	if GridManager.is_placement_blocked(cells_to_claim, building_item_id):
		return

	if GridManager.place_item(cells_to_claim, self):
		is_placed = true
		modulate = Color(1.0, 1.0, 1.0, 1.0) 
		area.area_entered.connect(_on_area_entered)
		
		if linked_partner != null:
			linked_partner.linked_partner = self 
			
			var next_entrance = load(scene_file_path).instantiate()
			next_entrance.is_entrance = true
			next_entrance.current_direction = current_direction
			next_entrance.rotation_degrees = rotation_degrees
			get_parent().add_child(next_entrance)
		else:
			var exit_preview = load(scene_file_path).instantiate()
			exit_preview.is_entrance = false 
			exit_preview.current_direction = current_direction
			exit_preview.rotation_degrees = rotation_degrees
			exit_preview.linked_partner = self 
			get_parent().add_child(exit_preview)

func rotate_belt() -> void:
	current_direction = (current_direction + 1) % 4 as Direction
	rotation_degrees += 90
	
	if not is_placed and is_instance_valid(linked_partner):
		linked_partner.current_direction = current_direction
		linked_partner.rotation_degrees = rotation_degrees
		
# --- ITEM HANDLING ---
func _on_area_entered(hit_area: Area2D) -> void:
	if not is_placed or not is_entrance or not is_instance_valid(linked_partner) or not linked_partner.is_placed: 
		return
	
	if hit_area.is_in_group("items"):
		hit_area.set_physics_process(false)
		hit_area.set_deferred("monitoring", false)
		hit_area.set_deferred("monitorable", false)
		hit_area.visible = false
		
		var world_forward = Vector2.RIGHT.rotated(global_rotation).round()
		var sideways_dir = Vector2(-world_forward.y, world_forward.x)
		var saved_lane_offset = (hit_area.global_position - global_position).project(sideways_dir)
		
		hit_area.global_position = Vector2(-99999, -99999)
		
		var distance = global_position.distance_to(linked_partner.global_position)
		var travel_time = distance / speed
		
		var timer = get_tree().create_timer(travel_time)
		timer.timeout.connect(_on_item_arrived.bind(hit_area, saved_lane_offset))

func _on_item_arrived(item: Area2D, saved_lane_offset: Vector2) -> void:
	if is_instance_valid(item) and is_instance_valid(linked_partner):
		item.global_position = linked_partner.global_position + saved_lane_offset
		item.visible = true
		
		if not linked_partner.ejecting_items.has(item):
			linked_partner.ejecting_items.append(item)

# --- EXIT EJECTION LOGIC ---
func _physics_process(delta: float) -> void:
	if not is_placed or is_entrance: 
		return
	
	var world_dir = Vector2.RIGHT.rotated(global_rotation).round()
	
	for item in ejecting_items.duplicate():
		if is_instance_valid(item):
			item.global_position += world_dir * speed * delta
			
			var distance_moved = (item.global_position - global_position).length()
			
			if distance_moved >= 32.0:
				item.set_physics_process(true)
				item.set_deferred("monitoring", true)
				item.set_deferred("monitorable", true)
				ejecting_items.erase(item)
		else:
			ejecting_items.erase(item)
