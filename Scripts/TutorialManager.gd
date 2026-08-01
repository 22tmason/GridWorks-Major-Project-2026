extends Node

signal step_changed(step_index: int, description: String)
signal tutorial_finished

var current_step: int = 0
var current_progress: int = 0

# Step Types: 
# "ui_toggle" -> Inventory open/closed state
# "tab_select" -> Switching crafting UI tabs
# "craft"      -> Hand-crafting an item
# "placement"  -> Placing a building on the grid
# "production" -> Machine producing/smelting an item

var tutorial_steps: Array = [
	# --- PHASE 1: UI & CRAFTING ---
	{
		"text": "Press 'E' to open your Inventory & Crafting menu.",
		"type": "ui_toggle",
		"target_state": true
	},
	{
		"text": "Craft 5 Straight Belts from the Logistics tab.",
		"type": "craft",
		"target_item": "straight_belt",
		"required_amount": 5
	},
	{
		"text": "Press 'E' to close your inventory.",
		"type": "ui_toggle",
		"target_state": false
	},

	# --- PHASE 2: BELTS & ROTATION ---
	{
		"text": "Place 3 Straight Belts on the ground. (Press 'R' to rotate, and right click to demolish the belt and have it refunded)",
		"type": "placement",
		"target_item": "straight_belt",
		"required_amount": 3
	},

	# --- PHASE 3: DRILLS & PROCESSING TAB ---
	{
		"text": "Press 'E' to open your inventory.",
		"type": "ui_toggle",
		"target_state": true
	},
	{
		"text": "Click on the 'Processing' tab at the top right.",
		"type": "tab_select",
		"target_tab": "processing"
	},
	{
		"text": "Craft 1 Mechanical Mining Drill.",
		"type": "craft",
		"target_item": "electric_drill",
		"required_amount": 1
	},
	{
		"text": "Press 'E' to close your inventory.",
		"type": "ui_toggle",
		"target_state": false
	},
	{
		"text": "Use WASD and zoom in/out (scroll) to find an iron ore deposit (greyish blue) and place the Mining Drill.",
		"type": "placement",
		"target_item": "electric_drill",
		"required_amount": 1
	},

	# --- PHASE 4: SMELTING (Furnace) ---
	{
		"text": "Craft and place 1 Stone Furnace near your drill.",
		"type": "placement",
		"target_item": "stone_furnace",
		"required_amount": 1
	},
	{
		"text": "Place Straight Belts to create a path for the ore from the drill output to the Furnace, leaving a one tile gap between the Furnace. (Press 'R' to rotate)",
		"type": "placement",
		"target_item": "straight_belt",
		"required_amount": 3
	},

	{
		"text": "Place an Inserter to feed raw ore into the Furnace, face it towards the belt, with the Furnace behind.",
		"type": "placement",
		"target_item": "inserter",
		"required_amount": 1
	},
	{
		"text": "Smelt raw ore into 1 Iron Ingot using the Stone Furnace.",
		"type": "production",
		"target_item": "iron_ingot",
		"required_amount": 1
	},

	# --- PHASE 5: BELT CORNERS & ROUTING ---
	{
		"text": "Place a Corner Belt to turn your conveyor line.",
		"type": "placement",
		"target_item": "corner_belt_right",
		"required_amount": 1
	},

	# --- PHASE 6: 1-INPUT PROCESSING (Processor MK1) ---
	{
		"text": "Craft and place a Processor MK1 from the Manufacturing tab.",
		"type": "placement",
		"target_item": "processor_mk1",
		"required_amount": 1
	},
	{
		"text": "Feed Iron Ingots into the Processor MK1 to produce an Intermediate Part in the same way as the Furnace",
		"type": "production",
		"target_item": "iron_gear",
		"required_amount": 1
	},

	# --- PHASE 7: 2-INPUT MANUFACTURING (Manufacturer MK1) ---
	{
		"text": "Craft and place a Manufacturer MK1.",
		"type": "placement",
		"target_item": "manufacturer_mk1",
		"required_amount": 1
	},
	{
		"text": "Feed both Iron Ingots and Copper Wire into the Manufacturer to produce Electronic Circuits!",
		"type": "production",
		"target_item": "electronic_circuit",
		"required_amount": 1
	}
]

func get_current_objective() -> String:
	if current_step < tutorial_steps.size():
		var step_data = tutorial_steps[current_step]
		if step_data.has("required_amount") and step_data["required_amount"] > 1:
			return step_data["text"] + " (%d/%d)" % [current_progress, step_data["required_amount"]]
		return step_data["text"]
	return "Tutorial Complete! You've mastered factory basics."

# Called when Inventory opens/closes
func notify_inventory_toggled(is_open: bool) -> void:
	_check_step("ui_toggle", func(step): return step["target_state"] == is_open)

# Called when UI Tab is clicked (logistics, processing, manufacturing, intermediates)
func notify_tab_selected(tab_name: String) -> void:
	_check_step("tab_select", func(step): return step["target_tab"].to_lower() == tab_name.to_lower())

# Called when player clicks hand-craft button
func notify_item_crafted(item_id: String) -> void:
	_check_step("craft", func(step): return step["target_item"] == item_id)

# Called when player places a building on grid
func notify_item_placed(item_id: String) -> void:
	_check_step("placement", func(step): 
		if step["target_item"] == "corner_belt_right":
			return item_id in ["corner_belt_right", "corner_belt_left"]
		return step["target_item"] == item_id
	)

# Called when a machine (Furnace, Processor, Manufacturer, Drill) produces an item
func notify_item_produced(item_id: String) -> void:
	_check_step("production", func(step): 
		if step["target_item"] in ["iron_plate", "iron_ingot"]:
			return item_id in ["iron_plate", "iron_ingot"]
		return step["target_item"] == item_id
	)

func _check_step(event_type: String, match_condition: Callable) -> void:
	if current_step >= tutorial_steps.size():
		return
		
	var step_data = tutorial_steps[current_step]
	if step_data["type"] == event_type and match_condition.call(step_data):
		current_progress += 1
		var required = step_data.get("required_amount", 1)
		
		if current_progress >= required:
			advance_step()
		else:
			step_changed.emit(current_step, get_current_objective())

func advance_step() -> void:
	current_step += 1
	current_progress = 0
	if current_step < tutorial_steps.size():
		step_changed.emit(current_step, get_current_objective())
	else:
		tutorial_finished.emit()
