extends Node2D

# --- MAP SETTINGS ---
@export var map_radius: int = 50 # Generates a 100x100 grid area (6400x6400 pixels!)
@export var tile_size: float = 64

# --- TILEMAP (UPDATED FOR GODOT 4.3) ---
@export var ground_tilemap: TileMapLayer # Changed this to TileMapLayer!

func _ready() -> void:
	_generate_sand_background()
	# _generate_resources() # We will uncomment this when you are ready for ores!

func _generate_resources() -> void:
	pass # (Your future FastNoiseLite ore generation will go here)

func _generate_sand_background() -> void:
	if not ground_tilemap:
		push_error("MapGenerator needs a TileMapLayer assigned!")
		return
		
	# The source ID of your sand tile in the TileSet (usually 0 or 1, check your TileSet tab)
	var source_id = 1 
	# The coordinate of the sand tile in the atlas (usually 0,0)
	var atlas_coord = Vector2i(0, 0) 
	
	# Loop through the grid and paint the sand tile everywhere!
	# The '6' at the end tells it to skip 6 spaces before placing the next giant tile
	for x in range(-map_radius, map_radius, 6):
		for y in range(-map_radius, map_radius, 6):
			ground_tilemap.set_cell(Vector2i(x, y), source_id, atlas_coord)
			
	print("Sand background generated!")
