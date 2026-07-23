extends Node2D

# --- UPDATED: Renamed to something more generic ---
@export var default_item_scene: PackedScene

func _unhandled_input(event: InputEvent) -> void:
	# 1. Handle single right-click
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		attempt_demolition()
		
	# 2. Handle click-and-drag for demolition
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		attempt_demolition()

# Extracted logic for demolishing and refunding
func attempt_demolition() -> void:
	var mouse_pos = get_global_mouse_position()
	var grid_cell = GridManager.world_to_grid(mouse_pos)
	
	# 1. Check if there is actually a building in this cell
	if GridManager.grid_data.has(grid_cell):
		# Grab the actual building node sitting in the grid
		var building_node = GridManager.grid_data[grid_cell]
		
		# 2. Safely extract its inventory item ID
		var item_to_refund = ""
		if "building_item_id" in building_node:
			item_to_refund = building_node.building_item_id
			
		# 3. Demolish the building from the world
		GridManager.remove_item(grid_cell)
		
		# 4. Refund the item to the inventory
		if item_to_refund != "":
			var success = InventoryManager.add_item(item_to_refund, 1)
			if success:
				print("Refunded 1x ", item_to_refund, " to inventory.")
			else:
				print("Inventory full! Could not refund ", item_to_refund)
				
func spawn_item() -> void:
	var mouse_pos = get_global_mouse_position()
	var current_grid_cell = GridManager.world_to_grid(mouse_pos)
	var snapped_position = GridManager.grid_to_world(current_grid_cell)
	
	if is_tile_clear_for_item(snapped_position):
		
		# --- FIX: Make sure the scene actually exists before trying to spawn it! ---
		if default_item_scene == null:
			print("Error: No item assigned to Main Level!")
			return
			
		var new_item = default_item_scene.instantiate()
		new_item.global_position = snapped_position
		add_child(new_item)
	else:
		print("Placement blocked: Item already exists at this coordinate.")


# --- SPATIAL CHECK HELPER FUNCTION ---
func is_tile_clear_for_item(target_global_position: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	
	query.position = target_global_position
	query.collide_with_areas = true 
	query.collide_with_bodies = true
	
	var results = space_state.intersect_point(query)
	
	for hit in results:
		var collider = hit["collider"]
		if collider.is_in_group("items"):
			return false 
			
	return true
