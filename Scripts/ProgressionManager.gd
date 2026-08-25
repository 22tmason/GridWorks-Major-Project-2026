extends Node

signal phase_unlocked(new_phase: int)

var current_phase: int = 0

# Maps Space Elevator phases to item/building IDs unlocked at each milestone
var phase_unlocks: Dictionary = {
	0: [
		"straight_belt_mk1", "corner_belt_right_mk1", "corner_belt_left_mk1", "underground_belt_mk1", "process_mk1", "manufacturer_mk1",
		"inserter", "drill_mk1", "furnace_mk1",
		"coal_ore", "iron_ore", "copper_ore", "iron_plate"
	],
	1: [
		"processor_mk1",
		"copper_wire", "iron_gear", "iron_rod"
	],
	2: [
		"manufacturer_mk1", "long_inserter",
		"electronic_circuit", "engine",
	],
	3: [
		"straight_belt_mk3", "corner_belt_right_mk3", "corner_belt_left_mk3", "underground_belt_mk3",
		"drill_mk3", "furnace_mk3", "processor_mk3", "manufacturer_mk2", "manufacturer_mk3",
		"advanced_circuit", "processing_circuit", "battery", "electric_motor", 
		"low_density_structure", "flying_robot_frame", "rocket_control_unit"
	]
}

func is_unlocked(item_id: String) -> bool:
	if item_id == "":
		return true
	for phase in range(current_phase + 1):
		if phase_unlocks.has(phase) and item_id in phase_unlocks[phase]:
			return true
	return false

func advance_phase() -> void:
	current_phase += 1
	phase_unlocked.emit(current_phase)
	InventoryManager.inventory_updated.emit()
	InventoryManager.hotbar_updated.emit()
