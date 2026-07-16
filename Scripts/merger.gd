extends Node2D

@onready var area: Area2D = $Area2D

var is_placed := false
var current_direction := 0 
var speed := 64.0

var output_route = Vector2(0, -1) 

# --- PERFECT ZIPPER TRACKING ---
var active_items = {} 
var queue = []
var center_occupant: Area2D = null

func _ready() -> void:
	if not is_placed:
		BuildManager.current_preview = self
		modulate.a = 0.5
	else:
		area.area_entered.connect(_on_area_entered)

# --- NEW: 1x1 Building footprint ---
func get_occupied_cells(center_cell: Vector2i) -> Array[Vector2i]:
	return [center_cell]

func _process(_delta: float) -> void:
	if is_placed: return
		
	var mouse_pos = get_global_mouse_position()
	var current_grid_cell = GridManager.world_to_grid(mouse_pos)
	global_position = GridManager.grid_to_world(current_grid_cell)

	# --- NEW: Universal Red/White Overlay Check ---
	var cells_to_check = get_occupied_cells(current_grid_cell)
	
	if GridManager.is_placement_blocked(cells_to_check):
		modulate = Color(1.0, 0.4, 0.4, 0.8) # Red if blocked
	else:
		modulate = Color(1.0, 1.0, 1.0, 0.5) # White if clear

func _unhandled_input(event: InputEvent) -> void:
	if not is_placed:
		if event is InputEventKey and event.keycode == KEY_R and event.pressed:
			rotation_degrees += 90
			current_direction = (current_direction + 1) % 4
			
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var current_grid_cell = GridManager.world_to_grid(get_global_mouse_position())
			
			# --- UPDATED: Pass the ARRAY of cells to the GridManager! ---
			var cells_to_claim = get_occupied_cells(current_grid_cell)
			if GridManager.place_item(cells_to_claim, self):
				is_placed = true
				modulate = Color(1.0, 1.0, 1.0, 1.0) # Reset color fully back to normal
				area.area_entered.connect(_on_area_entered)
				
				var next_merger = load(scene_file_path).instantiate()
				next_merger.current_direction = current_direction
				next_merger.rotation_degrees = rotation_degrees
				get_parent().add_child(next_merger)

func _on_area_entered(hit_area: Area2D) -> void:
	if hit_area.is_in_group("items") and not active_items.has(hit_area):
		hit_area.set_physics_process(false) 
		active_items[hit_area] = {"state": "waiting"}
		queue.append(hit_area)

func _physics_process(delta: float) -> void:
	if not is_placed: return
	
	var center = global_position
	var world_output_dir = output_route.rotated(global_rotation).round()
	
	# --- 1. CLEANUP ---
	var keys = active_items.keys()
	for item in keys:
		if not is_instance_valid(item):
			active_items.erase(item)
			queue.erase(item)
			if center_occupant == item: center_occupant = null

	# --- 2. ZIPPER CONTROLLER ---
	# Green light for the next item the exact millisecond the previous one is 24 pixels away.
	if center_occupant == null or center_occupant.global_position.distance_to(center) >= 24.0:
		while queue.size() > 0:
			var next_up = queue.pop_front()
			if is_instance_valid(next_up):
				center_occupant = next_up
				active_items[center_occupant]["state"] = "moving_to_center"
				break

	# --- 3. MOVEMENT LOGIC ---
	for item in active_items.keys():
		var data = active_items[item]
		
		if data["state"] == "moving_to_center":
			# Moves directly to the center. Bumper checks aren't needed here because the queue spaces them out perfectly.
			item.global_position = item.global_position.move_toward(center, speed * delta)
			
			if item.global_position.distance_to(center) < 1.0:
				item.global_position = center
				data["state"] = "moving_to_edge"
				
		elif data["state"] == "moving_to_edge":
			var edge_target = center + (world_output_dir * 32.0)
			
			# ONLY check the slim bumper to see if the immediate space ahead is clear
			if is_path_clear(item, world_output_dir):
				item.global_position = item.global_position.move_toward(edge_target, speed * delta)
				
				if item.global_position.distance_to(edge_target) < 1.0:
					item.global_position = edge_target
					item.set_physics_process(true)
					active_items.erase(item)

# --- Utilities ---
func is_path_clear(item: Area2D, world_dir: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = RectangleShape2D.new()
	
	# Slimmed-down bumper to prevent false positives
	if world_dir.x != 0:
		shape.size = Vector2(4, 20)
	else:
		shape.size = Vector2(20, 4)
		
	query.shape = shape
	query.transform = Transform2D(0, item.global_position + (world_dir * 24.0))
	query.collide_with_areas = true
	query.exclude = [item.get_rid()]
	
	var blockers = space_state.intersect_shape(query)
	for b in blockers:
		if b.collider.is_in_group("items"):
			if active_items.has(b.collider):
				continue # Items inside the merger ignore each other
			return false
	return true
