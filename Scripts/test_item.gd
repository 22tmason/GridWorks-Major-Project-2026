extends Area2D

var is_waiting_for_gap := false # Tracks if we were just dropped by an inserter

func _ready() -> void:
	add_to_group("items")

func _physics_process(delta: float) -> void:
	var space_state = get_world_2d().direct_space_state
	
	var current_cell = GridManager.world_to_grid(global_position)
	var tile_center = GridManager.grid_to_world(current_cell)
	
	# --- Use a tiny 4x4 box to bridge the microscopic gaps between tiles ---
	var query = PhysicsShapeQueryParameters2D.new()
	var query_shape = RectangleShape2D.new()
	query_shape.size = Vector2(4, 4)
	query.shape = query_shape
	query.transform = Transform2D(0, global_position)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.exclude = [self.get_rid()]
	
	var hits = space_state.intersect_shape(query)
	
	# Variables to safely store what we find
	var current_belt = null
	var found_collider = null
	var local_dir = Vector2.ZERO
	
# --- 1. Find the Belt (SMART CHECK FOR STRAIGHT & CORNER BELTS) ---
	for hit in hits:
		var collider = hit.collider
		
		# Find the main building (checking both the area and its parent)
		var building = null
		if "is_placed" in collider: building = collider
		elif collider.get_parent() and "is_placed" in collider.get_parent(): building = collider.get_parent()
		
		# Ensure it's placed
		if building and building.is_placed:
			# Find where the push direction is stored
			var p_dir = null
			if "push_direction" in collider: p_dir = collider.push_direction
			elif "push_direction" in building: p_dir = building.push_direction
			
			if p_dir != null:
				if current_belt == null:
					current_belt = building
					found_collider = collider
					local_dir = p_dir
				else:
					# Tie-breaker 1: Exit areas win to cleanly escape corners
					if "Exit" in collider.name:
						current_belt = building
						found_collider = collider
						local_dir = p_dir
					# Tie-breaker 2: Nearest to center
					elif "Exit" not in found_collider.name and "Entrance" not in found_collider.name:
						var dist_new = collider.global_position.distance_to(tile_center)
						var dist_old = found_collider.global_position.distance_to(tile_center)
						if dist_new < dist_old:
							current_belt = building
							found_collider = collider
							local_dir = p_dir
						
	# --- NEW FALLBACK: Cast a wider net ---
	if current_belt == null:
		var fallback_shape = RectangleShape2D.new()
		fallback_shape.size = Vector2(30, 30)
		query.shape = fallback_shape
		hits = space_state.intersect_shape(query)
		
		for hit in hits:
			var collider = hit.collider
			var building = null
			if "is_placed" in collider: building = collider
			elif collider.get_parent() and "is_placed" in collider.get_parent(): building = collider.get_parent()
			
			if building and building.is_placed:
				var p_dir = null
				if "push_direction" in collider: p_dir = collider.push_direction
				elif "push_direction" in building: p_dir = building.push_direction
				
				if p_dir != null:
					current_belt = building
					found_collider = collider
					local_dir = p_dir
					break
				
		query.shape = query_shape
						
	# --- 2. Move the Item ---
	if current_belt:
		# Safely extract variables
		var belt_speed = current_belt.get("speed") if "speed" in current_belt else 128.0
		var lane_offset = current_belt.get("lane_offset") if "lane_offset" in current_belt else 16.0
		var world_dir = local_dir.rotated(current_belt.global_rotation).round()
		
		var can_move = true
		
		# --- ROBUST Gap Waiting ---
		if is_waiting_for_gap:
			var gap_query = PhysicsShapeQueryParameters2D.new()
			var gap_shape = RectangleShape2D.new()
			gap_shape.size = Vector2(30, 30) 
			gap_query.shape = gap_shape
			gap_query.transform = Transform2D(0, global_position)
			gap_query.collide_with_areas = true
			gap_query.exclude = [self.get_rid()]
			
			var overlaps = space_state.intersect_shape(gap_query)
			var is_blocked = false
			
			for o in overlaps:
				if o.collider.is_in_group("items"):
					is_blocked = true
					break
					
			if is_blocked:
				can_move = false 
			else:
				is_waiting_for_gap = false 

		# --- ROBUST Queueing ---
		if can_move: 
			var queue_query = PhysicsShapeQueryParameters2D.new()
			var queue_shape = RectangleShape2D.new()
			
			if world_dir.x != 0:
				queue_shape.size = Vector2(4, 24) 
			else:
				queue_shape.size = Vector2(24, 4) 
			
			queue_query.shape = queue_shape
			queue_query.transform = Transform2D(0, global_position + (world_dir * 12.0))
			queue_query.collide_with_areas = true
			queue_query.exclude = [self.get_rid()]
			
			var blockers = space_state.intersect_shape(queue_query)
			
			for b in blockers:
				if b.collider.is_in_group("items"):
					can_move = false 
					break

		# --- End of Belt Logic ---
		var offset_from_center = global_position - tile_center
		var progress_forward = offset_from_center.dot(world_dir)
		var stop_distance = 16.0 
		
		if can_move and progress_forward > stop_distance:
			var next_tile_center = tile_center + (world_dir * 64.0)
			
			var belt_query = PhysicsShapeQueryParameters2D.new()
			belt_query.shape = query_shape 
			belt_query.transform = Transform2D(0, next_tile_center)
			belt_query.collide_with_areas = true
			
			var ahead_hits = space_state.intersect_shape(belt_query)
			var has_belt = false
			
			for h in ahead_hits: 
				var ahead_col = h.collider
				var ahead_build = null
				if "is_placed" in ahead_col: ahead_build = ahead_col
				elif ahead_col.get_parent() and "is_placed" in ahead_col.get_parent(): ahead_build = ahead_col.get_parent()
				
				if ahead_build and ahead_build.is_placed:
					if "push_direction" in ahead_col or "push_direction" in ahead_build:
						has_belt = true
						break
					
			if not has_belt:
				can_move = false
				global_position -= world_dir * (progress_forward - stop_distance)

		# --- Movement & Snapping ---
		if can_move:
			global_position += world_dir * belt_speed * delta
			
			var new_cell = GridManager.world_to_grid(global_position)
			var new_center = GridManager.grid_to_world(new_cell)
			
			if world_dir.y != 0: 
				var lane_1 = new_center.x + lane_offset
				var lane_2 = new_center.x - lane_offset
				var target_x = lane_1 if abs(global_position.x - lane_1) < abs(global_position.x - lane_2) else lane_2
				
				if global_position.x == new_center.x:
					target_x = lane_1
					
				global_position.x = move_toward(global_position.x, target_x, belt_speed * delta)
				
			elif world_dir.x != 0:
				var lane_1 = new_center.y + lane_offset
				var lane_2 = new_center.y - lane_offset
				var target_y = lane_1 if abs(global_position.y - lane_1) < abs(global_position.y - lane_2) else lane_2
				
				if global_position.y == new_center.y:
					target_y = lane_1
					
				global_position.y = move_toward(global_position.y, target_y, belt_speed * delta)
