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

func _process(_delta: float) -> void:
	if is_placed:
		return
		
	var mouse_pos = get_global_mouse_position()
	var current_grid_cell = GridManager.world_to_grid(mouse_pos)
	var snapped_position = GridManager.grid_to_world(current_grid_cell)
	
	global_position = snapped_position

func _unhandled_input(event: InputEvent) -> void:
	if is_placed: return
		
	# --- NEW: Rotate belt matching your straight belt logic ---
	if event is InputEventKey and event.keycode == KEY_R and event.pressed:
		rotate_belt()
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var cell = GridManager.world_to_grid(get_global_mouse_position())
		
		if GridManager.place_item(cell, self):
			is_placed = true
			modulate.a = 1.0 
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
# --- ITEM HANDLING ---
# --- ITEM HANDLING ---
func _on_area_entered(hit_area: Area2D) -> void:
	if not is_entrance: return 
	
	if hit_area.is_in_group("items") and is_instance_valid(linked_partner):
		hit_area.set_physics_process(false)
		hit_area.visible = false
		
		# --- NEW: SAVE THE LANE OFFSET ---
		# 1. Figure out which way the belt is facing
		var forward_dir = push_direction.rotated(global_rotation).round()
		# 2. Get the cross-axis (the line cutting left-to-right across the belt)
		var sideways_dir = Vector2(-forward_dir.y, forward_dir.x) 
		# 3. Extract ONLY the left/right offset from the item's current position
		var lane_offset = (hit_area.global_position - global_position).project(sideways_dir)
		
		# Send to the void so it doesn't block traffic
		hit_area.global_position = Vector2(-99999, -99999)
		
		var distance = global_position.distance_to(linked_partner.global_position)
		var travel_time = distance / speed 
		
		var timer = get_tree().create_timer(travel_time)
		# Pass the lane_offset through the bind so the exit knows where to place it!
		timer.timeout.connect(_on_item_arrived.bind(hit_area, lane_offset))

# Notice we added `lane_offset` as a required parameter here
func _on_item_arrived(item: Area2D, lane_offset: Vector2) -> void:
	if is_instance_valid(item) and is_instance_valid(linked_partner):
		
		# Teleport to the exit's center PLUS the saved lane offset!
		item.global_position = linked_partner.global_position + lane_offset
		item.visible = true
		
		if not linked_partner.ejecting_items.has(item):
			linked_partner.ejecting_items.append(item)

# --- EXACT STRAIGHT BELT PUSH LOGIC ---
# --- EXACT STRAIGHT BELT PUSH LOGIC ---
func _physics_process(delta: float) -> void:
	if not is_placed: return
	
	if not is_entrance:
		var world_dir = push_direction.rotated(global_rotation).round()
		
		for item in ejecting_items.duplicate():
			if is_instance_valid(item):
				item.global_position += world_dir * speed * delta
				
				# --- THE FIX: Measure only the distance traveled forward ---
				var offset_vector = item.global_position - global_position
				var distance_forward = offset_vector.dot(world_dir)
				
				# Now it will always push exactly to the flat edge of the 32px tile
				if distance_forward >= 32.0:
					item.set_physics_process(true)
					ejecting_items.erase(item)
			else:
				ejecting_items.erase(item)
