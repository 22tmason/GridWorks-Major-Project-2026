extends Node2D

# This allows us to drag and drop our test_item.tscn in the editor
@export var test_item_scene: PackedScene

func _unhandled_input(event: InputEvent) -> void:
	# Check for Right-Click (Demolish)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		
		# (We removed the lines that delete the preview so you can keep building!)
		
		# Find out what grid cell we are pointing at
		var mouse_pos = get_global_mouse_position()
		var grid_cell = GridManager.world_to_grid(mouse_pos)
		
		# Demolish whatever is in that cell!
		GridManager.remove_item(grid_cell)

func spawn_item() -> void:
	# 1. Figure out where the mouse is and snap it to the grid
	var mouse_pos = get_global_mouse_position()
	var current_grid_cell = GridManager.world_to_grid(mouse_pos)
	var snapped_position = GridManager.grid_to_world(current_grid_cell)
	
	# 2. NEW: Check if the physical space is actually empty
	if is_tile_clear_for_item(snapped_position):
		# 3. Create a brand new instance of the item
		var new_item = test_item_scene.instantiate()
		
		# 4. Force the item into the correct snapped position
		new_item.global_position = snapped_position
		
		# 5. Finally, add it to the game world!
		add_child(new_item)
	else:
		# Optional: Let you know in the console why it didn't spawn
		print("Placement blocked: Item already exists at this coordinate.")


# --- SPATIAL CHECK HELPER FUNCTION ---
func is_tile_clear_for_item(target_global_position: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	
	query.position = target_global_position
	# Ensure it detects your item's Area2D or CharacterBody2D
	query.collide_with_areas = true 
	query.collide_with_bodies = true
	
	var results = space_state.intersect_point(query)
	
	for hit in results:
		var collider = hit["collider"]
		# Check if the object we hit is in the "items" group
		if collider.is_in_group("items"):
			return false # The space is occupied!
			
	return true # The space is completely clear.
