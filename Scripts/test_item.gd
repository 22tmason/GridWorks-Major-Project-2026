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
	var current_belt = null
	
	# --- 1. Find the Belt (FIXED FOR SEAM FLIP-FLOPPING) ---
	for hit in hits:
		var collider = hit.collider
		if "is_placed" in collider and "push_direction" in collider:
			if current_belt == null:
				current_belt = collider
			else:
				# Tie-breaker 1: Exit areas win to cleanly escape corners
				if "Exit" in collider.name:
					current_belt = collider
				# Tie-breaker 2: If spanning two straight belts, pick the one belonging to our exact grid cell!
				elif "Exit" not in current_belt.name and "Entrance" not in current_belt.name:
					var dist_new = collider.global_position.distance_to(tile_center)
					var dist_old = current_belt.global_position.distance_to(tile_center)
					if dist_new < dist_old:
						current_belt = collider
						
	# --- 2. Move the Item ---
	if current_belt and current_belt.is_placed:
		var belt_speed = current_belt.speed
		var lane_offset = current_belt.lane_offset
		var local_dir = current_belt.push_direction
		var world_dir = local_dir.rotated(current_belt.global_rotation).round()
		
		var can_move = true
		
		# --- ROBUST Gap Waiting (Checking a full footprint, not just center points) ---
		if is_waiting_for_gap:
			var gap_query = PhysicsShapeQueryParameters2D.new()
			var gap_shape = RectangleShape2D.new()
			gap_shape.size = Vector2(30, 30) # A box roughly the size of your item's collision
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
				can_move = false # Freeze! The footprint isn't clear yet.
			else:
				is_waiting_for_gap = false # The footprint is 100% clear. Join the flow!
				
		
		# --- ROBUST Queueing (Thick Box Projection instead of RayCast) ---
		if can_move: 
			var queue_query = PhysicsShapeQueryParameters2D.new()
			var queue_shape = RectangleShape2D.new()
			
			# Create a wide but VERY THIN bumper (24px across, but only 4px deep)
			# We flip the dimensions based on which way we are moving
			if world_dir.x != 0:
				queue_shape.size = Vector2(4, 24) # Moving X: 4 wide, 24 tall
			else:
				queue_shape.size = Vector2(24, 4) # Moving Y: 24 wide, 4 tall
			
			queue_query.shape = queue_shape
			
			# Project this thin bumper exactly 24 pixels from the center of the item.
			# This puts it just barely in front of the item's visual graphic.
			queue_query.transform = Transform2D(0, global_position + (world_dir * 12.0))
			queue_query.collide_with_areas = true
			queue_query.exclude = [self.get_rid()]
			
			var blockers = space_state.intersect_shape(queue_query)
			
			for b in blockers:
				if b.collider.is_in_group("items"):
					can_move = false # Stop only when we are physically touching!
					break

		# --- End of Belt Logic (Looking for the next belt) ---
		var offset_from_center = global_position - tile_center
		var progress_forward = offset_from_center.dot(world_dir)
		var stop_distance = 16.0 
		
		if can_move and progress_forward > stop_distance:
			var next_tile_center = tile_center + (world_dir * 64.0)
			
			# Use a 4x4 box instead of a point so it doesn't slip through corner gaps
			var belt_query = PhysicsShapeQueryParameters2D.new()
			belt_query.shape = query_shape # Reuse the 4x4 box shape
			belt_query.transform = Transform2D(0, next_tile_center)
			belt_query.collide_with_areas = true
			
			var ahead_hits = space_state.intersect_shape(belt_query)
			var has_belt = false
			
			for h in ahead_hits: 
				if "is_placed" in h.collider and "push_direction" in h.collider:
					has_belt = true
					break
					
			if not has_belt:
				can_move = false
				global_position -= world_dir * (progress_forward - stop_distance)

		# --- Movement & Snapping ---
		if can_move:
			global_position += world_dir * belt_speed * delta
			
			# Recalculate grid in case movement pushed us into a new tile this exact frame
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
