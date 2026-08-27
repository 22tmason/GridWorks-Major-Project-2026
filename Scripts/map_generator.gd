extends Node2D

@export var player: Node2D
@export var chunk_size: int = 16
@export var render_distance: int = 8

@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var resource_layer: TileMapLayer = $ResourceLayer

# --- BIOME SETTINGS ---
# You will need to change these numbers to match the actual Source IDs in your TileSet!
var biome_1_sources: Array[int] = [0, 1, 2, 3, 4, 5] # e.g., Sandy Biome variations
var biome_2_sources: Array[int] = [6, 7, 8]    # e.g., Rocky/Gravel Biome variations
var biome_3_sources: Array[int] = [9, 10, 11]    # e.g., Dark Dirt Biome variations

# --- ORE TUNING ---
@export var iron_threshold: float = 0.55
@export var copper_threshold: float = -0.55 # Checked as less than this value
@export var coal_threshold: float = 0.55

# Change these to match your new transparent ore Source IDs
var iron_sources: Array[int] = [7, 9, 10] 
var copper_sources: Array[int] = [4, 5]
var coal_sources: Array[int] = [0, 1, 2]

# --- NOISE SETTINGS ---
var terrain_noise: FastNoiseLite
var resource_noise: FastNoiseLite
var coal_noise: FastNoiseLite

var generated_chunks: Dictionary = {}

func _ready() -> void:
	# Register resource layer so GridManager can erase depleted tiles
	GridManager.resource_layer = resource_layer
	_setup_noise()
	update_chunks(Vector2.ZERO)

func _setup_noise() -> void:
	# Controls the sprawling Biome regions
	terrain_noise = FastNoiseLite.new()
	terrain_noise.seed = randi()
	terrain_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	terrain_noise.frequency = 0.02 # Lowered slightly for larger, more natural biomes
	
	# Controls the iron and copper patches
	resource_noise = FastNoiseLite.new()
	resource_noise.seed = randi() 
	resource_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	resource_noise.frequency = 0.005

	# Controls the coal patches with a distinct seed
	coal_noise = FastNoiseLite.new()
	coal_noise.seed = randi() + 999
	coal_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	coal_noise.frequency = 0.005

func _process(_delta: float) -> void:
	if not player:
		return
		
	var player_grid = GridManager.world_to_grid(player.global_position)
	var player_chunk = Vector2i(
		floor(float(player_grid.x) / chunk_size),
		floor(float(player_grid.y) / chunk_size)
	)
	
	update_chunks(player_chunk)

func update_chunks(center_chunk: Vector2i) -> void:
	for x in range(-render_distance, render_distance + 1):
		for y in range(-render_distance, render_distance + 1):
			var chunk_to_check = center_chunk + Vector2i(x, y)
			var chunk_key = str(chunk_to_check)
			
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
			var c_val = coal_noise.get_noise_2d(current_cell.x, current_cell.y)
			
			if r_val > iron_threshold:
				spawn_resource_node(current_cell, "iron_ore")
			elif r_val < copper_threshold:
				spawn_resource_node(current_cell, "copper_ore")
			elif c_val > coal_threshold:
				spawn_resource_node(current_cell, "coal_ore")
			else:
				spawn_base_terrain(current_cell)

func spawn_base_terrain(cell: Vector2i) -> void:
	# 1. Use the terrain noise to determine the biome region
	var t_val = terrain_noise.get_noise_2d(cell.x, cell.y)
	var chosen_source_id: int
	
	if t_val < -0.15:
		# Biome 1
		var idx = abs(hash(cell)) % biome_1_sources.size()
		chosen_source_id = biome_1_sources[idx]
	elif t_val > 0.15:
		# Biome 3
		var idx = abs(hash(cell)) % biome_3_sources.size()
		chosen_source_id = biome_3_sources[idx]
	else:
		# Biome 2 (The transition space in the middle)
		var idx = abs(hash(cell)) % biome_2_sources.size()
		chosen_source_id = biome_2_sources[idx]
		
	# 2. Draw the background tile
	ground_layer.set_cell(cell, chosen_source_id, Vector2i(0, 0))

func spawn_resource_node(cell: Vector2i, resource_type: String) -> void:
	if GridManager.depleted_resources.has(cell):
		spawn_base_terrain(cell)
		return
		
	# --- THE FIX: Always draw the biome ground underneath the transparent ore! ---
	spawn_base_terrain(cell)
	
	var initial_amount = randi_range(120, 180)
	
	match resource_type:
		"iron_ore":
			var iron_index = abs(hash(cell) + 7) % iron_sources.size()
			resource_layer.set_cell(cell, iron_sources[iron_index], Vector2i(0, 0))
			
		"copper_ore":
			var copper_index = abs(hash(cell) + 13) % copper_sources.size()
			resource_layer.set_cell(cell, copper_sources[copper_index], Vector2i(0, 0))

		"coal_ore":
			var coal_index = abs(hash(cell) + 21) % coal_sources.size()
			resource_layer.set_cell(cell, coal_sources[coal_index], Vector2i(0, 0))

	GridManager.register_resource_node(cell, resource_type, initial_amount)
