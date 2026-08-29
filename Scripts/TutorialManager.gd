extends Node

signal step_changed(step_index: int, description: String)
signal tutorial_finished

var current_step: int = 0
var current_progress: int = 0

var tutorial_steps: Array = [
	# --- PHASE 1: UI & BATCH CRAFTING ---
	{
		"text": "Press 'E' to open your Inventory & Crafting menu.",
		"type": "ui_toggle",
		"target_state": true
	},
	{
		"text": "Use the Batch Size slider to craft 5 Straight Belts at once.",
		"type": "craft",
		"target_item": "straight_belt_mk1",
		"required_amount": 5
	},
	{
		"text": "Press 'E' to close your inventory.",
		"type": "ui_toggle",
		"target_state": false
	},

	# --- PHASE 2: BELTS & DEMOLITION ---
	{
		"text": "Place 3 Straight Belts on the ground. (Press 'R' to rotate)",
		"type": "placement",
		"target_item": "straight_belt_mk1",
		"required_amount": 3
	},
	{
		"text": "Right-click a placed belt to Demolish it and get a refund.",
		"type": "demolish",
		"required_amount": 1
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
		"text": "Craft 1 Mining Drill MK1.",
		"type": "craft",
		"target_item": "drill_mk1",
		"required_amount": 1
	},
	{
		"text": "Press 'E' to close your inventory.",
		"type": "ui_toggle",
		"target_state": false
	},
	{
		"text": "Press 'Q' to exit building mode, use WASD to move and scroll to zoom in/out to find an iron ore deposit, you can find out the type by hovering your mouse over it. Place the Drill there.",
		"type": "placement",
		"target_item": "drill_mk1",
		"required_amount": 1
	},

	# --- PHASE 4: SMELTING & AUTOMATION ---
	{
		"text": "Craft and place 1 Furnace a few tiles away from your drill.",
		"type": "placement",
		"target_item": "furnace_mk1",
		"required_amount": 1
	},
	{
		"text": "Place an Inserter in front of the furnace with its claw facing away to feed raw ore from the Drill into the Furnace (using belts to cover the distance).",
		"type": "placement",
		"target_item": "inserter",
		"required_amount": 1
	},
	{
		"text": "Left-click your Furnace, select the 'Iron Plate' recipe, and wait for it to smelt.",
		"type": "production",
		"target_item": "iron_plate",
		"required_amount": 1
	},
	
	# --- PHASE 5: STATISTICS & ENDGAME ---
	{
		"text": "Press 'P' to view your live Production Statistics.",
		"type": "stats_toggle",
		"target_state": true
	},
	{
		"text": "Press 'P' again to close the statistics panel.",
		"type": "stats_toggle",
		"target_state": false
	},
	{
		"text": "Use Belts to transport your finished Iron Plates into the Space Elevator. Continue to meet the delivery quotas to unlock new machines and finish the game!",
		"type": "delivery",
		"target_item": "iron_plate",
		"required_amount": 10
	}
]

func get_current_objective() -> String:
	if current_step < tutorial_steps.size():
		var step_data = tutorial_steps[current_step]
		if step_data.has("required_amount") and step_data["required_amount"] > 1:
			return step_data["text"] + " (%d/%d)" % [current_progress, step_data["required_amount"]]
		return step_data["text"]
	return "Tutorial Complete! Feed 100 Iron & Copper plates into the Space Elevator to unlock Phase 1."

func notify_inventory_toggled(is_open: bool) -> void:
	_check_step("ui_toggle", func(step): return step["target_state"] == is_open)

func notify_tab_selected(tab_name: String) -> void:
	_check_step("tab_select", func(step): return step["target_tab"].to_lower() == tab_name.to_lower())

func notify_item_crafted(item_id: String) -> void:
	_check_step("craft", func(step): return step["target_item"] == item_id)

func notify_item_placed(item_id: String) -> void:
	_check_step("placement", func(step): 
		if step["target_item"] == "corner_belt_right_mk1":
			return item_id in ["corner_belt_right_mk1", "corner_belt_left_mk1"]
		return step["target_item"] == item_id
	)

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

func notify_stats_toggled(is_open: bool) -> void:
	_check_step("stats_toggle", func(step): return step["target_state"] == is_open)

func notify_item_demolished() -> void:
	_check_step("demolish", func(step): return true)

func notify_item_delivered(item_id: String) -> void:
	_check_step("delivery", func(step): return step.get("target_item", item_id) == item_id)
