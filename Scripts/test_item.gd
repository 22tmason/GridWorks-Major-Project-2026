extends Area2D

# Tracks whether this specific item is locked onto the factory floor
var is_placed := false

func _process(_delta: float) -> void:
	# If it's already built, stop following the mouse!
	if is_placed:
		return
		
	# 1. Track the mouse cursor
	var mouse_pos = get_global_mouse_position()
	
	# 2. Convert to clean grid coordinates
	var current_grid_cell = GridManager.world_to_grid(mouse_pos)
	
	# 3. Get the absolute pixel center of that cell
	var snapped_position = GridManager.grid_to_world(current_grid_cell)
	
	# 4. Move the preview icon to the snapped position
	global_position = snapped_position

func _unhandled_input(event: InputEvent) -> void:
	# Only listen for clicks if this item hasn't been placed yet
	if is_placed:
		return
		
	# Detect left mouse button click
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var current_grid_cell = GridManager.world_to_grid(get_global_mouse_position())
		
		# Attempt to register this cell in the GridManager
		var success = GridManager.place_item(current_grid_cell, self)
		
		if success:
			is_placed = true
			# Optional: Change opacity or modulate color slightly to show it's built
			modulate.a = 1.0
