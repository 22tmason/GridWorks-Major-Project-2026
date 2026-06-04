extends Node

const CELL_SIZE := Vector2(64, 64)

# Tracks which building is in which cell -> Keys: Vector2i, Values: Node/String
var grid_data := {}

# Load your scenes here
var straight_belt_scene = preload("res://GridWorks Major Project 2026/Scenes/belt.tscn")
var corner_belt_scene = preload("res://GridWorks Major Project 2026/Scenes/corner_belt.tscn")

# --- NEW: Load the Inserter scene ---
var inserter_scene = preload("res://GridWorks Major Project 2026/Scenes/inserter.tscn") # Make sure this path is correct!

# ... rest of your script ...
func world_to_grid(world_pos: Vector2) -> Vector2i:
	var grid_x = floor(world_pos.x / CELL_SIZE.x)
	var grid_y = floor(world_pos.y / CELL_SIZE.y)
	return Vector2i(grid_x, grid_y)

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	var world_x = (grid_pos.x * CELL_SIZE.x) + (CELL_SIZE.x / 2.0)
	var world_y = (grid_pos.y * CELL_SIZE.y) + (CELL_SIZE.y / 2.0)
	return Vector2(world_x, world_y)

# Tries to place an item at a specific grid coordinate
func place_item(grid_pos: Vector2i, item_node: Node) -> bool:
	# Check if the cell is already occupied
	if grid_data.has(grid_pos):
		print("Cell ", grid_pos, " is already occupied!")
		return false
	
	# If empty, save the item node into our grid tracking dictionary
	grid_data[grid_pos] = item_node
	print("Successfully placed item at ", grid_pos)
	return true
