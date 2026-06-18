extends Node2D

@onready var area: Area2D = $Area2D

var is_placed := false
var current_direction := 0 
var speed := 64.0

var output_routes = [Vector2(0, -1), Vector2(-1, 0), Vector2(1, 0)]
var next_route_index := 0

# Dictionary tracking item -> { state, forbidden_route, route }
var active_items = {} 

func _ready() -> void:
	if not is_placed:
		BuildManager.current_preview = self
		modulate.a = 0.5
	else:
		area.area_entered.connect(_on_area_entered)

func _process(_delta: float) -> void:
	if is_placed:
		return
		
	var mouse_pos = get_global_mouse_position()
	var current_grid_cell = GridManager.world_to_grid(mouse_pos)
	global_position = GridManager.grid_to_world(current_grid_cell)

func _unhandled_input(event: InputEvent) -> void:
	if not is_placed:
		if event is InputEventKey and event.keycode == KEY_R and event.pressed:
			rotation_degrees += 90
			current_direction = (current_direction + 1) % 4
			
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var cell = GridManager.world_to_grid(get_global_mouse_position())
			if GridManager.place_item(cell, self):
				is_placed = true
				modulate.a = 1.0 
				area.area_entered.connect(_on_area_entered)
				
				var next_splitter = load(scene_file_path).instantiate()
				next_splitter.current_direction = current_direction
				next_splitter.rotation_degrees = rotation_degrees
				get_parent().add_child(next_splitter)

func _on_area_entered(hit_area: Area2D) -> void:
	if hit_area.is_in_group("items") and not active_items.has(hit_area):
		hit_area.set_physics_process(false) 
		
		# Figure out which side the item came from to prevent backflow
		var dir_from_item = (global_position - hit_area.global_position).normalized()
		var forbidden_route = -dir_from_item.round() 
		
		# Immediately send it to the center. We will evaluate routes once it gets there!
		active_items[hit_area] = {
			"state": "moving_to_center",
			"forbidden_route": forbidden_route,
			"route": Vector2.ZERO
		}

func _physics_process(delta: float) -> void:
	if not is_placed: return
	
	var center = global_position
	
	var keys = active_items.keys()
	for item in keys:
		if not is_instance_valid(item):
			active_items.erase(item)
			continue
			
		var data = active_items[item]
		
		# STEP 1: Pull item to the center
		if data["state"] == "moving_to_center":
			item.global_position = item.global_position.move_toward(center, speed * delta)
			
			if item.global_position.distance_to(center) < 1.0:
				item.global_position = center
				data["state"] = "evaluating_routes"
				
		# STEP 2: Find a valid exit lane that actually has a building
		elif data["state"] == "evaluating_routes":
			var valid_routes = []
			
			for local_route in output_routes:
				var world_route = local_route.rotated(global_rotation).round()
				
				# Only add the route if it's not the entrance AND there is a building there
				if world_route != data["forbidden_route"] and has_building_at(world_route):
					valid_routes.append(world_route)
			
			# If we found at least one valid path, pick the next one in the cycle
			if not valid_routes.is_empty():
				var chosen_route = valid_routes[next_route_index % valid_routes.size()]
				next_route_index += 1
				
				data["route"] = chosen_route
				data["state"] = "moving_to_edge"
				
			# If valid_routes IS empty, the item simply stays in the "evaluating_routes" state 
			# and waits exactly at the center until a building is placed!
				
		# STEP 3: Push the item out to the chosen lane
		elif data["state"] == "moving_to_edge":
			var world_dir = data["route"]
			var edge_target = center + (world_dir * 32.0)
			
			if is_path_clear(item, world_dir):
				item.global_position = item.global_position.move_toward(edge_target, speed * delta)
				
				if item.global_position.distance_to(edge_target) < 1.0:
					item.global_position = edge_target
					item.set_physics_process(true)
					active_items.erase(item)

# --- NEW: Checks the adjacent tile to see if a structure is placed there ---
func has_building_at(world_dir: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	
	# Check the dead-center of the tile 64 pixels away
	query.position = global_position + (world_dir * 64.0)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	var hits = space_state.intersect_point(query)
	for hit in hits:
		# If we hit something that ISN'T an item, we assume it's a valid belt/machine!
		if not hit.collider.is_in_group("items"):
			return true
			
	return false

func is_path_clear(item: Area2D, world_dir: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = RectangleShape2D.new()
	
	if world_dir.x != 0:
		shape.size = Vector2(4, 24)
	else:
		shape.size = Vector2(24, 4)
		
	query.shape = shape
	query.transform = Transform2D(0, item.global_position + (world_dir * 24.0))
	query.collide_with_areas = true
	query.exclude = [item.get_rid()]
	
	var blockers = space_state.intersect_shape(query)
	for b in blockers:
		if b.collider.is_in_group("items"):
			if active_items.has(b.collider):
				continue
			return false
	return true
