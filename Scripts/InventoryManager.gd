extends Node

signal inventory_updated

signal hotbar_updated

# 9 Slots total. The first 4 have defaults, the rest are empty!
var hotbar_items: Array[String] = [
	"straight_belt", "inserter", "drill_mk1", "furnace_mk1",
	"", "", "", "", "" 
]

# Tracks what item the player's mouse is currently hovering over
var hovered_item_id: String = ""

# Function to bind a new item to a slot
func set_hotbar_item(index: int, item_id: String) -> void:
	if index >= 0 and index < 9:
		hotbar_items[index] = item_id
		hotbar_updated.emit()
const INVENTORY_SIZE = 80 
var slots: Array = []

var item_database: Dictionary = {
	# --- LOGISTICS ---
	"straight_belt": {
		"name": "Straight Belt",
		"description": "Transports items in a straight line.",
		"category": "logistics",
		"subcategory": "Belts",
		"texture": "res://GridWorks Major Project 2026/Assets/Icons/YellowBeltIcon.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/belt.tscn"
	},
	"corner_belt_right": {
		"name": "Corner Belt Right",
		"description": "Turns the transport line to the right.",
		"category": "logistics",
		"subcategory": "Belts",
		"texture": "res://GridWorks Major Project 2026/Assets/Icons/CornerBeltRightIcon.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/corner_belt_right.tscn"
	},
	"corner_belt_left": {
		"name": "Corner Belt Left",
		"description": "Turns the transport line to the left.",
		"category": "logistics",
		"subcategory": "Belts",
		"texture": "res://GridWorks Major Project 2026/Assets/Icons/CornerBeltLeftIcon.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/corner_belt_left.tscn"
	},
	"inserter": {
		"name": "Standard Inserter",
		"description": "Moves items from one place to another.",
		"category": "logistics",
		"subcategory": "Inserters",
		"texture": "res://GridWorks Major Project 2026/Assets/Icons/InserterIcon.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/inserter.tscn"
	},
	"fast_inserter": {
		"name": "Fast Inserter",
		"description": "Moves items at a faster speed.",
		"category": "logistics",
		"subcategory": "Inserters",
		"texture": "res://GridWorks Major Project 2026/Assets/Icons/FastInserterIcon.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/fast_inserter.tscn"
	},
	"long_inserter": {
		"name": "Long Inserter",
		"description": "Moves items over a longer distance.",
		"category": "logistics",
		"subcategory": "Inserters",
		"texture": "res://GridWorks Major Project 2026/Assets/Icons/LongInserterIcon.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/long_inserter.tscn"
	},
	"splitter": {
		"name": "Splitter",
		"description": "Splits a single belt into two paths.",
		"category": "logistics",
		"subcategory": "Flow Control",
		"texture": "res://GridWorks Major Project 2026/Assets/Icons/SpliterIcon.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/splitter.tscn"
	},
	"merger": {
		"name": "Merger",
		"description": "Merges two belts into one path.",
		"category": "logistics",
		"subcategory": "Flow Control",
		"texture": "res://GridWorks Major Project 2026/Assets/Icons/MergerIcon.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/merger.tscn"
	},
	"underground_belt": {
		"name": "Underground Belt",
		"description": "Transports items underneath other structures.",
		"category": "logistics",
		"subcategory": "Belts",
		"texture": "res://GridWorks Major Project 2026/Assets/Icons/UndergroundBeltIcon.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/underground_belt.tscn"
	},

	# --- RESOURCE PROCESSING ---
	"drill_mk1": {
		"name": "Mining Drill MK1",
		"description": "Automatically extracts resources from the ground.",
		"category": "processing",
		"subcategory": "Drilling",
		"texture": "res://GridWorks Major Project 2026/Assets/Icons/drill_mk1_ICON.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/drill_mk1.tscn"
	},
	"drill_mk2": {
		"name": "Mining Drill MK2",
		"description": "Automatically extracts resources from the ground faster than the mk1 drill.",
		"category": "processing",
		"subcategory": "Drilling",
		"texture": "res://GridWorks Major Project 2026/Assets/Icons/drill_mk2_ICON-1.png.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/drill_mk2.tscn"
	},
	"drill_mk3": {
		"name": "Mining Drill MK3",
		"description": "Automatically extracts resources from the ground at maximum speed.",
		"category": "processing",
		"subcategory": "Drilling",
		"texture": "res://GridWorks Major Project 2026/Assets/Icons/drill_mk3_ICON-1.png.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/drill_mk3.tscn"
	},
	"furnace_mk1": {
		"name": "Furnace MK1",
		"description": "Smelts raw resources into usable items.",
		"category": "processing",
		"subcategory": "Smelting",
		"texture": "res://GridWorks Major Project 2026/Assets/Icons/furnace_mk1_ICON.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/furnace_mk1.tscn"
	},
	"furnace_mk2": {
		"name": "Furnace MK2",
		"description": "Smelts raw resources into usable items faster.",
		"category": "processing",
		"subcategory": "Smelting",
		"texture": "res://GridWorks Major Project 2026/Assets/Icons/furnace_mk2_ICON.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/furnace_mk2.tscn"
	},
	"furnace_mk3": {
		"name": "Furnace MK3",
		"description": "Smelts raw resources into usable items at maximum speed.",
		"category": "processing",
		"subcategory": "Smelting",
		"texture": "res://GridWorks Major Project 2026/Assets/Icons/furnace_mk3_ICON.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/furnace_mk3.tscn"
	},

	# --- MANUFACTURING ---
	"processor_mk1": {
		"name": "Processor MK1",
		"description": "Standard processing unit for basic automated crafting.",
		"category": "manufacturing",
		"subcategory": "Basic Processing",
		"texture": "res://GridWorks Major Project 2026/Assets/Icons/processor_mk1_ICON.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/processor_mk1.tscn"
	},
	"processor_mk2": {
		"name": "Processor MK2",
		"description": "Accelerated processing unit for basic automated crafting.",
		"category": "manufacturing",
		"subcategory": "Basic Processing",
		"texture": "res://GridWorks Major Project 2026/Assets/Icons/processor_mk2_ICON.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/processor_mk2.tscn"
	},
	"processor_mk3": {
		"name": "Processor MK3",
		"description": "Fastest processing unit for basic automated crafting.",
		"category": "manufacturing",
		"subcategory": "Basic Processing",
		"texture": "res://GridWorks Major Project 2026/Assets/Icons/processor_mk3_ICON.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/processor_mk3.tscn"
	},
	"manufacturer_mk1": {
		"name": "Manufacturer MK1",
		"description": "Basic manufacturing unit for complex crafting.",
		"category": "manufacturing",
		"subcategory": "Advanced Processing",
		"texture": "res://GridWorks Major Project 2026/Assets/Icons/ManufacturerMK1Icon.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/manufacturer_mk1.tscn"
	},
	"manufacturer_mk2": {
		"name": "Manufacturer MK2",
		"description": "Fast manufacturing unit for complex crafting.",
		"category": "manufacturing",
		"subcategory": "Advanced Processing",
		"texture": "res://GridWorks Major Project 2026/Assets/Icons/manufacturer_mk3_ICON.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/manufacturer_mk2.tscn"
	},
	"manufacturer_mk3": {
		"name": "Manufacturer MK3",
		"description": "Fastest manufacturing unit for complex crafting.",
		"category": "manufacturing",
		"subcategory": "Advanced Processing",
		"texture": "res://GridWorks Major Project 2026/Assets/Icons/manufacturer_mk2_ICON.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/manufacturer_mk3.tscn"
	},

	# --- INTERMEDIATE PARTS ---
	
	# -- RAW / SMELTED RESOURCES --
	"coal_ore": {
		"name": "Coal",
		"description": "A combustible fossil fuel mined from the earth that can be turned into plastic.",
		"category": "intermediates",
		"subcategory": "Raw Materials",
		"texture": "res://GridWorks Major Project 2026/Assets/Coal_ore (1).png",
		"scene": "res://GridWorks Major Project 2026/Scenes/coal_ore.tscn"
	},
	"iron_ore": {
		"name": "Iron Ore",
		"description": "A raw material that can be smelted into iron plates.",
		"category": "intermediates",
		"subcategory": "Raw Materials",
		"texture": "res://GridWorks Major Project 2026/Assets/Iron Ore.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/iron_ore.tscn"
	},
	"copper_ore": {
		"name": "Copper Ore",
		"description": "A raw material that can be smelted into copper plates.",
		"category": "intermediates",
		"subcategory": "Raw Materials",
		"texture": "res://GridWorks Major Project 2026/Assets/Copper Ore.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/copper_ore.tscn"
	},
	"iron_plate": {
		"name": "Iron Plate",
		"description": "A basic smelted iron plate used for crafting.",
		"category": "intermediates",
		"subcategory": "Refined Materials",
		"texture": "res://GridWorks Major Project 2026/Assets/Iron Plate.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/iron_plate.tscn" 
	},
	"copper_plate": {
		"name": "Copper Plate",
		"description": "A basic smelted copper plate used for crafting.",
		"category": "intermediates",
		"subcategory": "Refined Materials",
		"texture": "res://GridWorks Major Project 2026/Assets/Copper Plate.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/copper_plate.tscn"
	},
	"steel_plate": {
		"name": "Steel Plate",
		"description": "A tough, durable metal alloy.",
		"category": "intermediates",
		"subcategory": "Refined Materials",
		"texture": "res://GridWorks Major Project 2026/Assets/Steel_plate (2).png",
		"scene": "res://GridWorks Major Project 2026/Scenes/steel_plate.tscn"
	},
	"plastic_bar": {
		"name": "Plastic Bar",
		"description": "A versatile synthetic polymer.",
		"category": "intermediates",
		"subcategory": "Refined Materials",
		"texture": "res://GridWorks Major Project 2026/Assets/Plastic_bar (1).png",
		"scene": "res://GridWorks Major Project 2026/Scenes/plastic_bar.tscn"
	},

	# -- BASIC COMPONENTS (Processors) --
	"iron_gear": {
		"name": "Iron Gear Wheel",
		"description": "A basic mechanical component.",
		"category": "intermediates",
		"subcategory": "Components",
		"texture": "res://GridWorks Major Project 2026/Assets/Iron Gear.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/iron_gear.tscn"
	},
	"iron_rod": {
		"name": "Iron Rod",
		"description": "A sturdy iron rod.",
		"category": "intermediates",
		"subcategory": "Components",
		"texture": "res://GridWorks Major Project 2026/Assets/Iron_rod.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/iron_rod.tscn"
	},
	"copper_wire": {
		"name": "Copper Wire",
		"description": "Highly conductive wiring.",
		"category": "intermediates",
		"subcategory": "Components",
		"texture": "res://GridWorks Major Project 2026/Assets/Copper_wire (2).png",
		"scene": "res://GridWorks Major Project 2026/Scenes/copper_wire.tscn"
	},
	
	# -- ADVANCED COMPONENTS (Manufacturers) --
	"electronic_circuit": {
		"name": "Electronic Circuit",
		"description": "A basic electronic component used in machines. (Green)",
		"category": "intermediates",
		"subcategory": "Electronics",
		"texture": "res://GridWorks Major Project 2026/Assets/Electronic Circuit.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/electronic_circuit.tscn"
	},
	"advanced_circuit": {
		"name": "Advanced Circuit",
		"description": "A complex electronic component for high-tech machines. (Red)",
		"category": "intermediates",
		"subcategory": "Electronics",
		"texture": "res://GridWorks Major Project 2026/Assets/advanced_circuit (1).png",
		"scene": "res://GridWorks Major Project 2026/Scenes/advanced_circuit.tscn"
	},
	"processing_circuit": {
		"name": "Processing Circuit",
		"description": "The ultimate electronic computing component. (Blue)",
		"category": "intermediates",
		"subcategory": "Electronics",
		"texture": "res://GridWorks Major Project 2026/Assets/processing_circuit.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/processing_circuit.tscn"
	},
	"engine": {
		"name": "Engine",
		"description": "A standard combustion engine.",
		"category": "intermediates",
		"subcategory": "Mechanics",
		"texture": "res://GridWorks Major Project 2026/Assets/Engine.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/engine.tscn"
	},
	"battery": {
		"name": "Battery",
		"description": "A device to store energy for usage later.",
		"category": "intermediates",
		"subcategory": "Electronics",
		"texture": "res://GridWorks Major Project 2026/Assets/battery (1).png",
		"scene": "res://GridWorks Major Project 2026/Scenes/battery.tscn"
	},
	"electric_motor": {
		"name": "Electric Motor",
		"description": "A highly efficient electric motor.",
		"category": "intermediates",
		"subcategory": "Mechanics",
		"texture": "res://GridWorks Major Project 2026/Assets/electric_motor.png",
		"scene": "res://GridWorks Major Project 2026/Scenes/electric_motor.tscn"
	},
	"low_density_structure": {
		"name": "Low Density Structure",
		"description": "A lightweight but incredibly strong composite material.",
		"category": "intermediates",
		"subcategory": "Aerospace",
		"texture": "res://GridWorks Major Project 2026/Assets/low_density_structure (1).png",
		"scene": "res://GridWorks Major Project 2026/Scenes/low_density_structure.tscn"
	},
	"flying_robot_frame": {
		"name": "Flying Robot Frame",
		"description": "The chassis for aerial robotics.",
		"category": "intermediates",
		"subcategory": "Aerospace",
		"texture": "res://GridWorks Major Project 2026/Assets/flying_robot_frame (1).png",
		"scene": "res://GridWorks Major Project 2026/Scenes/flying_robot_frame.tscn"
	},
	# -- ENDGAME --
	"rocket_control_unit": {
		"name": "Rocket Control Unit",
		"description": "The final payload required to complete the Space Elevator.",
		"category": "intermediates",
		"subcategory": "Project Parts",
		"texture": "res://GridWorks Major Project 2026/Assets/rocket_control_unit (1).png",
		"scene": "res://GridWorks Major Project 2026/Scenes/rocket_control_unit.tscn"
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
