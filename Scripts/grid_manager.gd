extends Node

# The size of our factory grid cells
const CELL_SIZE := Vector2(64, 64)

# A dictionary we will use later to track which building is in which cell
var grid_data := {}

# Converts an exact pixel position (like a mouse click) into a clean grid coordinate (e.g., Col 2, Row 3)
func world_to_grid(world_pos: Vector2) -> Vector2i:
	var grid_x = floor(world_pos.x / CELL_SIZE.x)
	var grid_y = floor(world_pos.y / CELL_SIZE.y)
	return Vector2i(grid_x, grid_y)

# Converts a grid coordinate back to a pixel position (snapped to the center of the cell)
func grid_to_world(grid_pos: Vector2i) -> Vector2:
	var world_x = (grid_pos.x * CELL_SIZE.x) + (CELL_SIZE.x / 2.0)
	var world_y = (grid_pos.y * CELL_SIZE.y) + (CELL_SIZE.y / 2.0)
	return Vector2(world_x, world_y)
