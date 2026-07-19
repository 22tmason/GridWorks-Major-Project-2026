extends Node2D

@export var player: Node2D # Drag your Player node here in the inspector
@export var chunk_size: int = 16
@export var render_distance: int = 8 # How many chunks away from the player to load

@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var resource_layer: TileMapLayer = $ResourceLayer

@export_group("Iron Patch Tuning")
@export var iron_min_threshold: float = 0.55  # Anything above this starts spawning iron
@export var iron_core_threshold: float = 0.58 # Anything above this becomes the dense core

@export_group("Copper Patch Tuning")
@export var copper_min_threshold: float = 0.55  # Outermost edge boundary (positive value)
@export var copper_core_threshold: float = 0.58 # Dense core boundary (positive value)

# --- SOURCE SETTINGS ---
# Tracks SandyBackground 1, 2, and 3 from your inspector setup
var ground_sources: Array[int] = [0, 1, 2]

# Update these to match the actual Source IDs of your Iron assets
var iron_sources: Array[int] = [3, 4, 5]
var iron_edge_source: int = 6

# --- ASSIGN YOUR COPPER SOURCE IDs HERE ---
# Update these placeholder numbers (7, 8, 9, 10) to match your copper asset source IDs!
var copper_sources: Array[int] = [7, 9]
var copper_edge_source: int = 10

# --- NOISE SETTINGS ---
var terrain_noise: FastNoiseLite
var resource_noise: FastNoiseLite

# Keeps track of which chunks have already been built: {"(0, 0)": true}
var generated_chunks: Dictionary = {}

func _ready() -> void:
	_setup_noise()
	# Initial generation around the starting area
	update_chunks(Vector2.ZERO)

func _setup_noise() -> void:
	# 1. Noise for general terrain look
	terrain_noise = FastNoiseLite.new()
	terrain_noise.seed = randi()
	terrain_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	terrain_noise.frequency = 0.05
	
	# 2. Resource Noise: Lower frequency = MASSIVE, widely spaced patches
	resource_noise = FastNoiseLite.new()
	resource_noise.seed = randi() 
	resource_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	resource_noise.frequency = 0.005

func _process(_delta: float) -> void:
	if not player:
		return
		
	# Convert player position into grid cell coords, then into chunk coords
	var player_grid = GridManager.world_to_grid(player.global_position)
	var player_chunk = Vector2i(
		floor(float(player_grid.x) / chunk_size),
		floor(float(player_grid.y) / chunk_size)
	)
	
	update_chunks(player_chunk)

func update_chunks(center_chunk: Vector2i) -> void:
	# Loop through a square region around the player's current chunk
	for x in range(-render_distance, render_distance + 1):
		for y in range(-render_distance, render_distance + 1):
			var chunk_to_check = center_chunk + Vector2i(x, y)
			var chunk_key = str(chunk_to_check)
			
			# Only generate if we haven't touched this chunk yet
			if not generated_chunks.has(chunk_key):
				generated_chunks[chunk_key] = true
				generate_chunk(chunk_to_check)

func generate_chunk(chunk_pos: Vector2i) -> void:
	var start_x = chunk_pos.x * chunk_size
	var start_y = chunk_pos.y * chunk_size
	
	for x in range(chunk_size):
		for y in range(chunk_size):
			var current_cell = Vector2i(start_x + x, start_y + y)
			var r_val = resource_noise.get_noise_2d(current_cell.x, current_cell.y)
			
			# --- IRON PATCHES ---
			if r_val > iron_min_threshold:
				if r_val < iron_core_threshold:
					spawn_resource_node(current_cell, "iron_ore_edge")
				else:
					spawn_resource_node(current_cell, "iron_ore")
					
			# --- COPPER PATCHES ---
			elif r_val < -copper_min_threshold:
				if r_val > -copper_core_threshold:
					spawn_resource_node(current_cell, "copper_ore_edge")
				else:
					spawn_resource_node(current_cell, "copper_ore")
					
			# --- DESERT BACKGROUND ---
			else:
				spawn_base_terrain(current_cell)

func spawn_base_terrain(cell: Vector2i) -> void:
	# Scramble the grid coordinates cleanly using the global hash() function
	var pseudo_random_index = abs(hash(cell)) % ground_sources.size()
	var chosen_source_id = ground_sources[pseudo_random_index]
	
	# Paint using the chosen source sheet at its native (0,0) position
	ground_layer.set_cell(cell, chosen_source_id, Vector2i(0, 0))

func spawn_resource_node(cell: Vector2i, resource_type: String) -> void:
	# 1. Match the background math exactly here so the ground tiles match seamlessly under ore patches
	var pseudo_random_index = abs(hash(cell)) % ground_sources.size()
	var chosen_ground_id = ground_sources[pseudo_random_index]
	ground_layer.set_cell(cell, chosen_ground_id, Vector2i(0, 0)) 
	
	# 2. Paint the specific resource graphic on top
	match resource_type:
		"iron_ore":
			var iron_index = abs(hash(cell) + 7) % iron_sources.size()
			var chosen_iron_source = iron_sources[iron_index]
			resource_layer.set_cell(cell, chosen_iron_source, Vector2i(0, 0))
			
		"iron_ore_edge":
			resource_layer.set_cell(cell, iron_edge_source, Vector2i(0, 0))
			
		"copper_ore":
			# Uses a different hash offset (+13) to cycle through variations distinctly from iron
			var copper_index = abs(hash(cell) + 13) % copper_sources.size()
			var chosen_copper_source = copper_sources[copper_index]
			resource_layer.set_cell(cell, chosen_copper_source, Vector2i(0, 0))
			
		"copper_ore_edge":
			resource_layer.set_cell(cell, copper_edge_source, Vector2i(0, 0))

	# 3. Register the ore data into the global grid tracker
	GridManager.register_resource_node(cell, resource_type)
