extends Node

const CELL_SIZE := Vector2(64, 64)

# Tracks which building is in which cell -> Keys: Vector2i, Values: Node/String
var grid_data := {}
# Inside your GridManager.gd script
var resource_data: Dictionary = {}

# Load your scenes here
var straight_belt_mk1_scene = preload("res://GridWorks Major Project 2026/Scenes/belt_mk1.tscn")
var corner_belt_right_mk1_scene = preload("res://GridWorks Major Project 2026/Scenes/corner_belt_right_mk1.tscn")
var corner_belt_left_mk1_scene = preload("res://GridWorks Major Project 2026/Scenes/corner_belt_left_mk1.tscn")
var inserter_scene = preload("res://GridWorks Major Project 2026/Scenes/inserter.tscn") 
# GridManager.gd

# Tracks cell quantities: { Vector2i(x,y): {"type": "iron_ore", "amount": 500} }
var resource_layer: TileMapLayer = null


func get_resource_at_cell(cell: Vector2i) -> String:
	if resource_data.has(cell) and resource_data[cell]["amount"] > 0:
		return resource_data[cell]["type"]
	return ""

# Add this near your other variables at the top of grid_manager.gd
var depleted_resources: Dictionary = {}

func register_resource_node(cell: Vector2i, type_name: String, amount: int = 500) -> void:
	# 1. Don't spawn it if the player already mined it completely
	if depleted_resources.has(cell): 
		return
	# 2. Don't overwrite the amount if we just loaded partial amounts from a save file
	if resource_data.has(cell): 
		return 

	resource_data[cell] = {
		"type": type_name,
		"amount": amount
	}

func consume_resource_under_drill(occupied_cells: Array[Vector2i]) -> String:
	for cell in occupied_cells:
		if resource_data.has(cell) and resource_data[cell]["amount"] > 0:
			resource_data[cell]["amount"] -= 1
			
			if resource_data[cell]["amount"] <= 0:
				resource_data.erase(cell)
				# NEW: Track that this cell is permanently dead
				depleted_resources[cell] = true 
				if resource_layer:
					resource_layer.erase_cell(cell) 
					
			return get_resource_at_cell(cell) 
	return ""
func world_to_grid(world_pos: Vector2) -> Vector2i:
	var grid_x = floor(world_pos.x / CELL_SIZE.x)
	var grid_y = floor(world_pos.y / CELL_SIZE.y)
	return Vector2i(grid_x, grid_y)

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	var world_x = (grid_pos.x * CELL_SIZE.x) + (CELL_SIZE.x / 2.0)
	var world_y = (grid_pos.y * CELL_SIZE.y) + (CELL_SIZE.y / 2.0)
	return Vector2(world_x, world_y)

# Tries to place an item at a specific grid coordinate
# Key: Vector2i(cell), Value: String ("iron_ore" / "copper_ore")
var natural_resources: Dictionary = {}
	
func is_placement_blocked(cells: Array[Vector2i], item_id: String = "") -> bool:
	if not BuildManager.is_placement_safe():
		return true # Briefly block placement
	# 1. Check if the physical grid space is blocked
	for cell in cells:
		if grid_data.has(cell):
			return true # Blocked by another building!
			
	# 2. Check if we are out of stock (if an ID was provided)
	if item_id != "" and InventoryManager.get_item_count(item_id) <= 0:
		return true # Blocked by empty inventory!
		
	return false # Clear to place!


# --- UPGRADED: Handles grid placement AND inventory consumption! ---
func place_item(cells: Array[Vector2i], item_node: Node) -> bool:
	if not BuildManager.is_placement_safe():
		return false
	# 1. Extract the item ID safely
	var cost_id = ""
	if "building_item_id" in item_node:
		cost_id = item_node.building_item_id
		
	# 2. Check if we actually have enough to place this
	if cost_id != "" and InventoryManager.get_item_count(cost_id) <= 0:
		print("GridManager: Not enough items to place!")
		return false
		
	# 3. Double check that all cells are still physically clear
	for cell in cells:
		if grid_data.has(cell):
			return false
			
	# 4. Consume the item from the inventory BEFORE placing
	if cost_id != "":
		InventoryManager.consume_item(cost_id, 1)
		TutorialManager.notify_item_placed(cost_id)
	
	# 5. Claim every requested cell in the dictionary
	for cell in cells:
		grid_data[cell] = item_node
	AudioManager.play_sound(AudioManager.build_sound)
	print("Successfully placed item covering cells: ", cells)
	return true
	

# --- UPDATED DEMOLISH FUNCTION ---
func remove_item(grid_pos: Vector2i) -> void:
	if grid_data.has(grid_pos):
		var item_to_remove = grid_data[grid_pos]
		
		# 1. Find EVERY cell in the grid that belongs to this specific building
		var cells_to_clear = []
		for cell in grid_data:
			if grid_data[cell] == item_to_remove:
				cells_to_clear.append(cell)
				
		# --- NEW: Sweep for loose items sitting on these tiles ---
		var all_loose_items = get_tree().get_nodes_in_group("items")
		for item in all_loose_items:
			var item_cell = world_to_grid(item.global_position)
			if item_cell in cells_to_clear:
				if "item_id" in item:
					# Try to add to inventory; if successful, delete the item from the belt
					if InventoryManager.add_item(item.item_id, 1):
						item.queue_free()

		# --- NEW: Recover items trapped in machine input buffers ---
		if "input_buffer" in item_to_remove and item_to_remove.input_buffer is Array:
			for buffered_item in item_to_remove.input_buffer:
				InventoryManager.add_item(buffered_item, 1)
				
		elif "input_inventory" in item_to_remove and item_to_remove.input_inventory is Dictionary:
			for buffered_item in item_to_remove.input_inventory.keys():
				InventoryManager.add_item(buffered_item, item_to_remove.input_inventory[buffered_item])
				
		# 2. Erase all of those cells so the space is empty again!
		for cell in cells_to_clear:
			grid_data.erase(cell)
		
		# 3. Destroy the physical building
		if is_instance_valid(item_to_remove):
			AudioManager.play_sound(AudioManager.demolish_sound)
			item_to_remove.queue_free()
			if get_node_or_null("/root/TutorialManager"):
				TutorialManager.notify_item_demolished()
			
		print("Demolished item! Cleared cells: ", cells_to_clear)
