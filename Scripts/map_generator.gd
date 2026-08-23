extends Node2D

@export var player: Node2D
@export var chunk_size: int = 16
@export var render_distance: int = 8

@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var resource_layer: TileMapLayer = $ResourceLayer

@export_group("Iron Patch Tuning")
@export var iron_min_threshold: float = 0.55
@export var iron_core_threshold: float = 0.58

@export_group("Copper Patch Tuning")
@export var copper_min_threshold: float = 0.55
@export var copper_core_threshold: float = 0.58

# --- NEW: COAL PATCH TUNING ---
@export_group("Coal Patch Tuning")
@export var coal_min_threshold: float = 0.55
@export var coal_core_threshold: float = 0.58

var ground_sources: Array[int] = [0, 1, 2]

var iron_sources: Array[int] = [3, 4, 5]
var iron_edge_source: int = 6

var copper_sources: Array[int] = [7, 9]
var copper_edge_source: int = 10

# --- NEW: COAL SOURCE IDs ---
var coal_sources: Array[int] = [1, 2, 8]
var coal_edge_source: int = 0

# --- NOISE SETTINGS ---
var terrain_noise: FastNoiseLite
var resource_noise: FastNoiseLite
var coal_noise: FastNoiseLite # Dedicated noise layer for coal patches

var generated_chunks: Dictionary = {}

func _ready() -> void:
	# Register resource layer so GridManager can erase depleted tiles
	GridManager.resource_layer = resource_layer
	_setup_noise()
	update_chunks(Vector2.ZERO)

func _setup_noise() -> void:
	terrain_noise = FastNoiseLite.new()
	terrain_noise.seed = randi()
	terrain_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	terrain_noise.frequency = 0.05
	
	resource_noise = FastNoiseLite.new()
	resource_noise.seed = randi() 
	resource_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	resource_noise.frequency = 0.005

	# Setup coal noise with a distinct seed
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
					
			# --- COAL PATCHES ---
			elif c_val > coal_min_threshold:
				if c_val < coal_core_threshold:
					spawn_resource_node(current_cell, "coal_ore_edge")
				else:
					spawn_resource_node(current_cell, "coal_ore")
					
			# --- DESERT BACKGROUND ---
			else:
				spawn_base_terrain(current_cell)

func spawn_base_terrain(cell: Vector2i) -> void:
	var pseudo_random_index = abs(hash(cell)) % ground_sources.size()
	var chosen_source_id = ground_sources[pseudo_random_index]
	ground_layer.set_cell(cell, chosen_source_id, Vector2i(0, 0))

func spawn_resource_node(cell: Vector2i, resource_type: String) -> void:
	var pseudo_random_index = abs(hash(cell)) % ground_sources.size()
	var chosen_ground_id = ground_sources[pseudo_random_index]
	ground_layer.set_cell(cell, chosen_ground_id, Vector2i(0, 0)) 
	
	var initial_amount = 50 # Default edge amount
	
	match resource_type:
		"iron_ore":
			initial_amount = randi_range(120, 180)# Core density
			var iron_index = abs(hash(cell) + 7) % iron_sources.size()
			resource_layer.set_cell(cell, iron_sources[iron_index], Vector2i(0, 0))
		"iron_ore_edge":
			initial_amount = randi_range(40, 60)
			resource_layer.set_cell(cell, iron_edge_source, Vector2i(0, 0))
			
		"copper_ore":
			initial_amount = randi_range(120, 180)
			var copper_index = abs(hash(cell) + 13) % copper_sources.size()
			resource_layer.set_cell(cell, copper_sources[copper_index], Vector2i(0, 0))
		"copper_ore_edge":
			initial_amount = randi_range(40, 60)
			resource_layer.set_cell(cell, copper_edge_source, Vector2i(0, 0))

		"coal_ore":
			initial_amount = randi_range(120, 180)
			var coal_index = abs(hash(cell) + 21) % coal_sources.size()
			resource_layer.set_cell(cell, coal_sources[coal_index], Vector2i(0, 0))
		"coal_ore_edge":
			initial_amount = randi_range(40, 60)
			resource_layer.set_cell(cell, coal_edge_source, Vector2i(0, 0))

	GridManager.register_resource_node(cell, resource_type, initial_amount)
