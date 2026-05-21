extends Area2D

# Tracks whether this specific item has been dropped onto the factory floor
var is_placed := false

func _process(_delta: float) -> void:
	if is_placed:
		return
		
	var mouse_pos = get_global_mouse_position()
	var current_grid_cell = GridManager.world_to_grid(mouse_pos)
	var snapped_position = GridManager.grid_to_world(current_grid_cell)
	
	global_position = snapped_position

func _unhandled_input(event: InputEvent) -> void:
	if is_placed:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		is_placed = true
		modulate.a = 1.0

func _physics_process(delta: float) -> void:
	if not is_placed:
		return
		
	var overlapping_belts = get_overlapping_areas()
	
	# --- DIAGNOSTIC PRINT ---
	# Open your Output tab at the bottom of Godot to see what this says!
	if Engine.get_physics_frames() % 60 == 0: 
		print("Item is checking under its feet. Found areas count: ", overlapping_belts.size())
	
	for belt in overlapping_belts:
		if "is_placed" in belt and belt.is_placed and "push_direction" in belt:
			var belt_speed = belt.speed
			var belt_dir = belt.push_direction
			var lane_offset = belt.lane_offset
			
			# 1. Forward Momentum
			global_position += belt_dir * belt_speed * delta
			
			# 2. Lane Snapping
			if belt_dir.y != 0: 
				var target_x: float
				if global_position.x >= belt.global_position.x:
					target_x = belt.global_position.x + lane_offset
				else:
					target_x = belt.global_position.x - lane_offset
				global_position.x = move_toward(global_position.x, target_x, belt_speed * delta)
				
			elif belt_dir.x != 0: 
				var target_y: float
				if global_position.y >= belt.global_position.y:
					target_y = belt.global_position.y + lane_offset
				else:
					target_y = belt.global_position.y - lane_offset
				global_position.y = move_toward(global_position.y, target_y, belt_speed * delta)
				
			break
