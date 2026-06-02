extends Node2D

# This allows us to drag and drop our test_item.tscn in the editor
@export var test_item_scene: PackedScene

func _unhandled_input(event: InputEvent) -> void:
	# Listen for Left Mouse Button clicks
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		
		# Make sure we actually assigned a scene in the inspector
		if test_item_scene:
			spawn_item()

func spawn_item() -> void:
	# 1. Create a brand new instance of the item
	var new_item = test_item_scene.instantiate()
	
	# 2. Figure out where the mouse is and snap it to the grid
	var mouse_pos = get_global_mouse_position()
	var current_grid_cell = GridManager.world_to_grid(mouse_pos)
	
	# 3. Force the item into the correct snapped position
	new_item.global_position = GridManager.grid_to_world(current_grid_cell)
	
	# 4. Finally, add it to the game world!
	add_child(new_item)
