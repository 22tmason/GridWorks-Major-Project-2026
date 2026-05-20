extends Area2D

func _process(_delta: float) -> void:
	# 1. Find exactly where the mouse cursor is on the screen
	var mouse_pos = get_global_mouse_position()
	
	# 2. Ask the GridManager what grid cell (e.g., Col 2, Row 3) the mouse is hovering over
	var current_grid_cell = GridManager.world_to_grid(mouse_pos)
	
	# 3. Ask the GridManager for the exact dead-center pixel position of that specific cell
	var snapped_position = GridManager.grid_to_world(current_grid_cell)
	
	# 4. Teleport our test item to that perfectly snapped position
	global_position = snapped_position
	
