extends Node

const SAVE_PATH = "user://factory_save.json"
var pending_load: bool = false

func save_game() -> void:
	var main_level = get_tree().current_scene
	var map_gen = main_level.get_node_or_null("MapGenerator") 
	var seeds = {}
	if map_gen:
		seeds["terrain"] = map_gen.terrain_noise.seed
		seeds["resource"] = map_gen.resource_noise.seed
		seeds["coal"] = map_gen.coal_noise.seed

	var res_data_str = {}
	for cell in GridManager.resource_data:
		res_data_str["%d,%d" % [cell.x, cell.y]] = GridManager.resource_data[cell]
		
	var depleted_str = []
	for cell in GridManager.depleted_resources:
		depleted_str.append("%d,%d" % [cell.x, cell.y])

	var save_data = {
		"inventory": InventoryManager.slots,
		"hotbar": InventoryManager.hotbar_items,
		"progression_phase": ProgressionManager.current_phase,
		"map_seeds": seeds,
		"resource_data": res_data_str,
		"depleted_resources": depleted_str,
		"buildings": [],
		"loose_items": [],
		"elevator_data": {} # --- NEW: Save Space Elevator progress ---
	}
	
	var processed_buildings = []
	for cell in GridManager.grid_data:
		var building = GridManager.grid_data[cell]
		if building in processed_buildings: continue
		processed_buildings.append(building)
		
		if "building_item_id" in building and building.building_item_id != "":
			var b_data = {
				"pos_x": building.global_position.x,
				"pos_y": building.global_position.y,
				"item_id": building.building_item_id,
				"direction": building.current_direction if "current_direction" in building else 0,
				"rotation": building.rotation_degrees,
			}
			if "selected_recipe" in building: b_data["selected_recipe"] = building.selected_recipe
			if "input_buffer" in building: b_data["input_buffer"] = building.input_buffer
			if "input_inventory" in building: b_data["input_inventory"] = building.input_inventory
			if "current_deliveries" in building: b_data["current_deliveries"] = building.current_deliveries
			save_data["buildings"].append(b_data)

	var loose_items = []
	for item in get_tree().get_nodes_in_group("items"):
		if "item_id" in item and item.item_id != "":
			loose_items.append({
				"id": item.item_id,
				"pos_x": item.global_position.x,
				"pos_y": item.global_position.y
			})
	save_data["loose_items"] = loose_items

	# --- NEW: Extract Space Elevator progress ---
	for child in main_level.get_children():
		if "phase_requirements" in child and "current_deliveries" in child:
			save_data["elevator_data"]["current_deliveries"] = child.current_deliveries
			break

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()
		print("Game Saved Successfully!")

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("No save file found!")
		return
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var content = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(content) != OK: return
	var save_data = json.get_data()
	
	InventoryManager.slots = save_data.get("inventory", InventoryManager.slots)
	
	var loaded_hotbar = save_data.get("hotbar", [])
	if loaded_hotbar.size() > 0:
		InventoryManager.hotbar_items.assign(loaded_hotbar)
		
	InventoryManager.inventory_updated.emit()
	InventoryManager.hotbar_updated.emit()
	
	ProgressionManager.current_phase = save_data.get("progression_phase", 0)
	ProgressionManager.phase_unlocked.emit(ProgressionManager.current_phase) 
	
	GridManager.depleted_resources.clear()
	if save_data.has("depleted_resources"):
		for cell_str in save_data["depleted_resources"]:
			var parts = cell_str.split(",")
			GridManager.depleted_resources[Vector2i(int(parts[0]), int(parts[1]))] = true

	GridManager.resource_data.clear()
	if save_data.has("resource_data"):
		for cell_str in save_data["resource_data"]:
			var parts = cell_str.split(",")
			GridManager.resource_data[Vector2i(int(parts[0]), int(parts[1]))] = save_data["resource_data"][cell_str]
	
	var main_level = get_tree().current_scene
	var map_gen = main_level.get_node_or_null("MapGenerator")
	
	if map_gen and save_data.has("map_seeds"):
		map_gen.terrain_noise.seed = save_data["map_seeds"]["terrain"]
		map_gen.resource_noise.seed = save_data["map_seeds"]["resource"]
		map_gen.coal_noise.seed = save_data["map_seeds"]["coal"]
		
		map_gen.generated_chunks.clear()
		map_gen.ground_layer.clear()
		map_gen.resource_layer.clear()
		
		var player = main_level.get_node_or_null("Player") 
		if player:
			var player_grid = GridManager.world_to_grid(player.global_position)
			var player_chunk = Vector2i(floor(float(player_grid.x) / map_gen.chunk_size), floor(float(player_grid.y) / map_gen.chunk_size))
			map_gen.update_chunks(player_chunk)
			
		for cell in GridManager.depleted_resources:
			map_gen.resource_layer.erase_cell(cell)
		
	var old_buildings = []
	for cell in GridManager.grid_data.keys():
		var building = GridManager.grid_data[cell]
		if is_instance_valid(building) and not building in old_buildings:
			# --- NEW: DO NOT DESTROY THE PRE-PLACED SPACE ELEVATOR! ---
			if "phase_requirements" in building:
				continue
			old_buildings.append(building)
			building.queue_free()
			
	GridManager.grid_data.clear()
	
	for item in get_tree().get_nodes_in_group("items"):
		if is_instance_valid(item):
			item.queue_free()
			
	# --- NEW: RESTORE SPACE ELEVATOR DATA & RE-REGISTER ITS FOOTPRINT ---
	for child in main_level.get_children():
		if "phase_requirements" in child and "current_deliveries" in child:
			child.current_phase = ProgressionManager.current_phase
			child._init_phase_tracker() 
			
			if save_data.has("elevator_data") and save_data["elevator_data"].has("current_deliveries"):
				var saved_del = save_data["elevator_data"]["current_deliveries"]
				for k in saved_del.keys():
					child.current_deliveries[k] = int(saved_del[k])
					
			# Reclaim its 5x5 footprint in the newly wiped GridManager!
			if child.has_method("_register_fixed_footprint"):
				child._register_fixed_footprint()
			break
		
	# Rebuild Factory
	for b_data in save_data.get("buildings", []):
		var item_id = b_data["item_id"]
		if not InventoryManager.item_database.has(item_id): continue
		
		var scene_path = InventoryManager.item_database[item_id]["scene"]
		var building = load(scene_path).instantiate()
		
		if "current_direction" in building: building.current_direction = b_data["direction"]
		building.rotation_degrees = b_data["rotation"]
		building.is_placed = true
		
		if b_data.has("pos_x"):
			building.global_position = Vector2(b_data["pos_x"], b_data["pos_y"])
		else:
			var old_cell = Vector2i(b_data["grid_x"], b_data["grid_y"])
			building.global_position = GridManager.grid_to_world(old_cell)
			if "processor" in item_id or "furnace" in item_id:
				building.global_position += Vector2(32.0, 32.0)
				
		var anchor_cell = GridManager.world_to_grid(building.global_position - Vector2(1, 1))
		var cells_to_claim = building.get_occupied_cells(anchor_cell)
		
		main_level.add_child(building)
		
		for c in cells_to_claim:
			GridManager.grid_data[c] = building

		if "selected_recipe" in building and b_data.has("selected_recipe"): building.set_active_recipe(b_data["selected_recipe"])
		
		if "input_buffer" in building and b_data.has("input_buffer"): 
			building.input_buffer.assign(b_data["input_buffer"])
			
		if "input_inventory" in building and b_data.has("input_inventory"): 
			building.input_inventory.clear()
			for k in b_data["input_inventory"].keys():
				building.input_inventory[k] = int(b_data["input_inventory"][k])
				
		if "current_deliveries" in building and b_data.has("current_deliveries"): 
			building.current_deliveries.clear()
			for k in b_data["current_deliveries"].keys():
				building.current_deliveries[k] = int(b_data["current_deliveries"][k])

	if save_data.has("loose_items"):
		for i_data in save_data["loose_items"]:
			var id = i_data["id"]
			if InventoryManager.item_database.has(id):
				var scene_path = InventoryManager.item_database[id]["scene"]
				var new_item = load(scene_path).instantiate()
				new_item.global_position = Vector2(i_data["pos_x"], i_data["pos_y"])
				main_level.add_child(new_item)
