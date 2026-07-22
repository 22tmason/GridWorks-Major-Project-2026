extends Node

signal inventory_updated

const INVENTORY_SIZE = 80 
var slots: Array = []

var item_database: Dictionary = {
	# --- LOGISTICS ---
	"straight_belt": {
		"name": "Straight Belt",
		"description": "Transports items in a straight line.",
		"category": "logistics",
		"texture": "res://GridWorks Major Project 2026/Assets/Icons/YellowBeltIcon.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/belt.tscn"
	},
	"corner_belt_right": {
		"name": "Corner Belt Right",
		"description": "Turns the transport line to the right.",
		"category": "logistics",
		"texture": "res://GridWorks Major Project 2026/Assets/Icons/CornerBeltRightIcon.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/corner_belt_right.tscn"
	},
	"corner_belt_left": {
		"name": "Corner Belt Left",
		"description": "Turns the transport line to the left.",
		"category": "logistics",
		"texture": "res://GridWorks Major Project 2026/Assets/Icons/CornerBeltLeftIcon.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/corner_belt_left.tscn"
	},
	"inserter": {
		"name": "Standard Inserter",
		"description": "Moves items from one place to another.",
		"category": "logistics",
		"texture": "res://GridWorks Major Project 2026/Assets/Icons/InserterIcon.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/inserter.tscn"
	},
	"fast_inserter": {
		"name": "Fast Inserter",
		"description": "Moves items at a faster speed.",
		"category": "logistics",
		"texture": "res://GridWorks Major Project 2026/Assets/Icons/FastInserterIcon.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/fast_inserter.tscn"
	},
	"long_inserter": {
		"name": "Long Inserter",
		"description": "Moves items over a longer distance.",
		"category": "logistics",
		"texture": "res://GridWorks Major Project 2026/Assets/Icons/LongInserterIcon.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/long_inserter.tscn"
	},
	"splitter": {
		"name": "Splitter",
		"description": "Splits a single belt into two paths.",
		"category": "logistics",
		"texture": "res://GridWorks Major Project 2026/Assets/Icons/SpliterIcon.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/splitter.tscn"
	},
	"merger": {
		"name": "Merger",
		"description": "Merges two belts into one path.",
		"category": "logistics",
		"texture": "res://GridWorks Major Project 2026/Assets/Icons/MergerIcon.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/merger.tscn"
	},
	"underground_belt": {
		"name": "Underground Belt",
		"description": "Transports items underneath other structures.",
		"category": "logistics",
		"texture": "res://GridWorks Major Project 2026/Assets/Icons/UndergroundBeltIcon.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/underground_belt.tscn"
	},

	# --- RESOURCE PROCESSING ---
	"electric_drill": {
		"name": "Mechanical Mining Drill",
		"description": "Automatically extracts resources from the ground.",
		"category": "processing",
		"texture": "res://GridWorks Major Project 2026/Assets/Icons/MechanicalDrillIcon.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/electric_drill.tscn"
	},
	"stone_furnace": {
		"name": "Stone Furnace",
		"description": "Smelts raw resources into usable items.",
		"category": "processing",
		"texture": "res://GridWorks Major Project 2026/Assets/Icons/StoneFurnaceIcon.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/stone_furnace.tscn"
	},

	# --- MANUFACTURING ---
	"processor_mk1": {
		"name": "Processor MK1",
		"description": "Basic processing unit for automated crafting.",
		"category": "manufacturing",
		"texture": "res://GridWorks Major Project 2026/Assets/Icons/ProcesserMK1Icon.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/processor_mk1.tscn"
	},
	"manufacturer_mk1": {
		"name": "Manufacturer MK1",
		"description": "Basic manufacturing unit for complex crafting.",
		"category": "manufacturing",
		"texture": "res://GridWorks Major Project 2026/Assets/Icons/ManufacturerMK1Icon.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/manufacturer_mk1.tscn"
	},

	# --- INTERMEDIATE PARTS ---
	"iron_plate": {
		"name": "Iron Ingot",
		"description": "A basic smelted iron ingot used for crafting.",
		"category": "intermediates",
		"texture": "res://GridWorks Major Project 2026/Assets/Iron Plate.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/iron_ingot.tscn" 
	},
	"copper_wire": {
		"name": "Copper Ingot",
		"description": "A basic smelted copper ingot used for crafting.",
		"category": "intermediates",
		"texture": "res://GridWorks Major Project 2026/Assets/Copper Ingot.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/copper_ingot.tscn"
	},
	"electronic_circuit": {
		"name": "Electronic Circuit",
		"description": "A basic electronic component used in machines.",
		"category": "intermediates",
		"texture": "res://GridWorks Major Project 2026/Assets/Electronic Circuit.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/electronic_circuit.tscn"
	}
}

func _ready() -> void:
	slots.resize(INVENTORY_SIZE)
	for i in range(INVENTORY_SIZE):
		slots[i] = {"id": "", "quantity": 0}
	
	# Testing items
	# add_item("straight_belt", 20)
	# add_item("electric_drill", 2)

func add_item(item_id: String, amount: int) -> bool:
	if not item_database.has(item_id): return false
	for i in range(INVENTORY_SIZE):
		if slots[i]["id"] == item_id:
			slots[i]["quantity"] += amount
			inventory_updated.emit()
			return true
	for i in range(INVENTORY_SIZE):
		if slots[i]["id"] == "":
			slots[i]["id"] = item_id
			slots[i]["quantity"] = amount
			inventory_updated.emit()
			return true
	return false

func remove_item_at_slot(slot_index: int, amount: int = 1) -> void:
	if slot_index < 0 or slot_index >= INVENTORY_SIZE: return
	if slots[slot_index]["id"] != "":
		slots[slot_index]["quantity"] -= amount
		if slots[slot_index]["quantity"] <= 0:
			slots[slot_index]["id"] = ""
			slots[slot_index]["quantity"] = 0
		inventory_updated.emit()

# Returns the total amount of a specific item across all inventory slots
func get_item_count(item_id: String) -> int:
	var total = 0
	for slot in slots:
		if slot["id"] == item_id:
			total += slot["quantity"]
	return total

# Deducts the amount from the inventory, handling stacks correctly
func consume_item(item_id: String, amount: int = 1) -> bool:
	if get_item_count(item_id) < amount:
		return false
	
	var amount_left = amount
	for i in range(INVENTORY_SIZE):
		if slots[i]["id"] == item_id:
			var slot_qty = slots[i]["quantity"]
			if slot_qty >= amount_left:
				remove_item_at_slot(i, amount_left)
				return true
			else:
				amount_left -= slot_qty
				remove_item_at_slot(i, slot_qty)
	return false
