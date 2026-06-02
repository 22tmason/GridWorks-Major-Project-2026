extends Area2D

@onready var raycast: RayCast2D = $RayCast2D 

func _ready() -> void:
	# --- Tag this object so the RayCast knows what it's looking at ---
	add_to_group("item")

func _physics_process(delta: float) -> void:
	var space_state = get_world_2d().direct_space_state
	
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
	
	# --- 1. Find the Belt ---
	for hit in hits:
		var collider = hit.collider
		
		# Because your child areas HAVE the script, we only need this one check!
		# It works for Straight Belts AND Corner Belt child areas.
		if "is_placed" in collider and "push_direction" in collider:
			current_belt = collider
			break
			
	# --- 2. Move the Item ---
	if current_belt and current_belt.is_placed:
		var belt_speed = current_belt.speed
		var lane_offset = current_belt.lane_offset
		
		# Get the hardcoded direction from the Inspector (e.g., Vector2.DOWN)
		var local_dir = current_belt.push_direction
		
		# Rotate that variable by the node's physical rotation in the world!
		# .round() ensures we get clean whole numbers like (1, 0) instead of (0.9999, 0)
		var world_dir = local_dir.rotated(current_belt.global_rotation).round()
		
		# --- Queuing Logic ---
		raycast.target_position = world_dir * 32.0
		raycast.force_raycast_update()
		
		var can_move = true
		
		if raycast.is_colliding():
			var hit_object = raycast.get_collider()
			if hit_object and hit_object.is_in_group("item"):
				can_move = false
		
		# --- Movement & Snapping ---
		if can_move:
			# Move the item using the correctly rotated world direction
			global_position += world_dir * belt_speed * delta
			
			var current_cell = GridManager.world_to_grid(global_position)
			var tile_center = GridManager.grid_to_world(current_cell)
			
			if world_dir.y != 0: 
				var target_x: float
				if global_position.x >= tile_center.x:
					target_x = tile_center.x + lane_offset
				else:
					target_x = tile_center.x - lane_offset
				global_position.x = move_toward(global_position.x, target_x, belt_speed * delta)
				
			elif world_dir.x != 0:
				var target_y: float
				if global_position.y >= tile_center.y:
					target_y = tile_center.y + lane_offset
				else:
					target_y = tile_center.y - lane_offset
				global_position.y = move_toward(global_position.y, target_y, belt_speed * delta)
