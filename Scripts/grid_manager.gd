extends Node

const CELL_SIZE := Vector2(64, 64)

# Tracks which building is in which cell -> Keys: Vector2i, Values: Node/String
var grid_data := {}

# Load your scenes here
var straight_belt_scene = preload("res://GridWorks Major Project 2026/Scenes/belt.tscn")
var corner_belt_right_scene = preload("res://GridWorks Major Project 2026/Scenes/corner_belt_right.tscn")
var corner_belt_left_scene = preload("res://GridWorks Major Project 2026/Scenes/corner_belt_left.tscn")
var inserter_scene = preload("res://GridWorks Major Project 2026/Scenes/inserter.tscn") 

func world_to_grid(world_pos: Vector2) -> Vector2i:
	var grid_x = floor(world_pos.x / CELL_SIZE.x)
	var grid_y = floor(world_pos.y / CELL_SIZE.y)
	return Vector2i(grid_x, grid_y)

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	var world_x = (grid_pos.x * CELL_SIZE.x) + (CELL_SIZE.x / 2.0)
	var world_y = (grid_pos.y * CELL_SIZE.y) + (CELL_SIZE.y / 2.0)
	return Vector2(world_x, world_y)

# Tries to place an item at a specific grid coordinate
# --- NEW: Checks if a placement is valid without actually placing it ---
func is_placement_blocked(cells: Array[Vector2i]) -> bool:
	for cell in cells:
		if grid_data.has(cell):
			return true # Blocked!
	return false # Clear!

# --- UPGRADED: Now accepts an ARRAY of cells instead of just one ---
func place_item(cells: Array[Vector2i], item_node: Node) -> bool:
	# 1. Double check that all cells are still clear
	if is_placement_blocked(cells):
		return false
	
	# 2. Claim every requested cell in the dictionary
	for cell in cells:
		grid_data[cell] = item_node
		
	print("Successfully placed item covering cells: ", cells)
	return true

# --- NEW DEMOLISH FUNCTION ---
# --- UPDATED DEMOLISH FUNCTION ---
func remove_item(grid_pos: Vector2i) -> void:
	if grid_data.has(grid_pos):
		var item_to_remove = grid_data[grid_pos]
		
		# 1. Find EVERY cell in the grid that belongs to this specific building
		var cells_to_clear = []
		for cell in grid_data:
			if grid_data[cell] == item_to_remove:
				cells_to_clear.append(cell)
				
		# 2. Erase all of those cells so the space is empty again!
		for cell in cells_to_clear:
			grid_data.erase(cell)
		
		# 3. Destroy the physical building
		if is_instance_valid(item_to_remove):
			item_to_remove.queue_free()
			
		print("Demolished item! Cleared cells: ", cells_to_clear)
