extends Node2D

@export var default_item_scene: PackedScene

# Dynamic tooltip for hovered resources
var resource_tooltip: Label

func _ready() -> void:
	_setup_resource_tooltip()
	
	if SaveManager.pending_load:
		SaveManager.pending_load = false
		SaveManager.call_deferred("load_game")

func _setup_resource_tooltip() -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	
	resource_tooltip = Label.new()
	resource_tooltip.visible = false
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.08, 0.85)
	style.border_color = Color(0.4, 0.4, 0.4, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	
	resource_tooltip.add_theme_stylebox_override("normal", style)
	resource_tooltip.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	resource_tooltip.add_theme_font_size_override("font_size", 14)
	canvas.add_child(resource_tooltip)

func _process(_delta: float) -> void:
	_update_resource_hover_tooltip()
	
	var machine_ui = get_tree().get_first_node_in_group("machine_ui")
	if $InventoryUI.visible or (machine_ui and machine_ui.visible):
		return
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if BuildManager.current_preview == null:
			attempt_item_pickup()

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not Input.is_key_pressed(KEY_SHIFT):
		attempt_demolition()

func _unhandled_input(event: InputEvent) -> void:
	var machine_ui = get_tree().get_first_node_in_group("machine_ui")
	if $InventoryUI.visible or (machine_ui and machine_ui.visible):
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if BuildManager.current_preview == null:
			attempt_item_pickup()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if not Input.is_key_pressed(KEY_SHIFT):
			attempt_demolition()
		
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if not Input.is_key_pressed(KEY_SHIFT):
			attempt_demolition()


func attempt_item_pickup() -> void:
	var mouse_pos = get_global_mouse_position()
	var space_state = get_world_2d().direct_space_state
	
	var query = PhysicsPointQueryParameters2D.new()
	query.position = mouse_pos
	query.collide_with_areas = true
	query.collide_with_bodies = false
	
	var hits = space_state.intersect_point(query)
	for hit in hits:
		var collider = hit.collider
		if collider.is_in_group("items"):
			var item_id = collider.get("item_id")
			if item_id:
				if InventoryManager.add_item(item_id, 1):
					collider.queue_free()
					return

func _update_resource_hover_tooltip() -> void:
	# Hide tooltip if inventory is open
	if $InventoryUI.visible:
		resource_tooltip.visible = false
		return

	# --- NEW: ACTION RECOGNITION (Quantity in Hand) ---
	if BuildManager.current_preview != null and BuildManager.current_item_id != "":
		var count = InventoryManager.get_item_count(BuildManager.current_item_id)
		var item_name = InventoryManager.item_database[BuildManager.current_item_id]["name"]
		
		resource_tooltip.text = "Placing: %s\nIn Inventory: %d" % [item_name, count]
		resource_tooltip.global_position = get_viewport().get_mouse_position() + Vector2(16, 16)
		resource_tooltip.visible = true
		
		# Visual warning if out of stock
		if count <= 0:
			resource_tooltip.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1.0))
		else:
			resource_tooltip.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		return

	# Fallback to normal resource scanning if not holding a building
	var mouse_pos = get_global_mouse_position()
	var grid_cell = GridManager.world_to_grid(mouse_pos)

	if GridManager.resource_data.has(grid_cell):
		var res_info = GridManager.resource_data[grid_cell]
		if res_info["amount"] > 0:
			var res_type = res_info["type"].replace("_ore", "").replace("_edge", "").capitalize()
			resource_tooltip.text = "%s Node\nQuantity: %d" % [res_type, res_info["amount"]]
			resource_tooltip.global_position = get_viewport().get_mouse_position() + Vector2(16, 16)
			resource_tooltip.visible = true
			resource_tooltip.add_theme_color_override("font_color", Color(1, 1, 1, 1)) # Reset color
			return

	resource_tooltip.visible = false

func attempt_demolition() -> void:
	var mouse_pos = get_global_mouse_position()
	var grid_cell = GridManager.world_to_grid(mouse_pos)
	
	if GridManager.grid_data.has(grid_cell):
		var building_node = GridManager.grid_data[grid_cell]
		
		# --- THE FIX: Make the Space Elevator indestructible! ---
		if "phase_requirements" in building_node:
			return
			
		var item_to_refund = ""
		if "building_item_id" in building_node:
			item_to_refund = building_node.building_item_id
			
		var all_loose_items = get_tree().get_nodes_in_group("items")
		for item in all_loose_items:
			var item_cell = GridManager.world_to_grid(item.global_position)
			
			if GridManager.grid_data.has(item_cell) and GridManager.grid_data[item_cell] == building_node:
				if "item_id" in item:
					if InventoryManager.add_item(item.item_id, 1):
						item.queue_free()
			
		if "input_buffer" in building_node and building_node.input_buffer is Array:
			for buffered_item in building_node.input_buffer:
				InventoryManager.add_item(buffered_item, 1)
				
		elif "input_inventory" in building_node and building_node.input_inventory is Dictionary:
			for buffered_item in building_node.input_inventory.keys():
				InventoryManager.add_item(buffered_item, building_node.input_inventory[buffered_item])

		GridManager.remove_item(grid_cell)
		if item_to_refund != "":
			InventoryManager.add_item(item_to_refund, 1)

func spawn_item() -> void:
	var mouse_pos = get_global_mouse_position()
	var current_grid_cell = GridManager.world_to_grid(mouse_pos)
	var snapped_position = GridManager.grid_to_world(current_grid_cell)
	
	if is_tile_clear_for_item(snapped_position):
		if default_item_scene == null: return
		var new_item = default_item_scene.instantiate()
		new_item.global_position = snapped_position
		add_child(new_item)

func is_tile_clear_for_item(target_global_position: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = target_global_position
	query.collide_with_areas = true 
	query.collide_with_bodies = true
	
	var results = space_state.intersect_point(query)
	for hit in results:
		if hit["collider"].is_in_group("items"):
			return false 
	return true
