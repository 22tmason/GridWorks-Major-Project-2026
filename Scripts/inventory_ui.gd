extends CanvasLayer

@export var slot_ui_scene: PackedScene = preload("res://GridWorks Major Project 2026/Scenes/InventorySlot.tscn")

@onready var inventory_grid = $MainPanel/HBoxContainer/LeftInventorySection/VBoxContainer/InventoryGrid

# References to our 4 automated category tab grids
@onready var logistics_grid: GridContainer = $MainPanel/HBoxContainer/RightCraftingSection/VBoxContainer/TabContainer/Logistics
@onready var processing_grid: GridContainer = $MainPanel/HBoxContainer/RightCraftingSection/VBoxContainer/TabContainer/Processing
@onready var manufacturing_grid: GridContainer = $MainPanel/HBoxContainer/RightCraftingSection/VBoxContainer/TabContainer/Manufacturing
@onready var intermediates_grid: GridContainer = $MainPanel/HBoxContainer/RightCraftingSection/VBoxContainer/TabContainer/Intermediates

func _ready() -> void:
	InventoryManager.inventory_updated.connect(populate_ui_views)
	build_static_structure()
	populate_ui_views()

func build_static_structure() -> void:
	# 1. Clear default mock items
	for child in inventory_grid.get_children(): child.queue_free()
	for child in logistics_grid.get_children(): child.queue_free()
	for child in processing_grid.get_children(): child.queue_free()
	for child in manufacturing_grid.get_children(): child.queue_free()
	for child in intermediates_grid.get_children(): child.queue_free()
	
	# 2. Build empty slots in the player inventory pane
	for i in range(InventoryManager.INVENTORY_SIZE):
		var slot_instance = slot_ui_scene.instantiate()
		inventory_grid.add_child(slot_instance)
		
	# 3. Scan the item database and sort recipes into their respective tabs
	for item_key in InventoryManager.item_database.keys():
		var item_data = InventoryManager.item_database[item_key]
		var craft_slot = slot_ui_scene.instantiate()
		
		# Direct the slot instance to the matching Tab GridContainer
		match item_data["category"]:
			"logistics":
				logistics_grid.add_child(craft_slot)
			"processing":
				processing_grid.add_child(craft_slot)
			"manufacturing":
				manufacturing_grid.add_child(craft_slot)
			"intermediates":
				intermediates_grid.add_child(craft_slot)
				
		craft_slot.setup_crafting_slot(item_key)

func populate_ui_views() -> void:
	# Dynamically update quantities inside the player inventory panel
	var inv_slots_ui = inventory_grid.get_children()
	for i in range(InventoryManager.INVENTORY_SIZE):
		var slot_data = InventoryManager.slots[i]
		inv_slots_ui[i].setup_inventory_slot(i, slot_data["id"], slot_data["quantity"])

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_E or event.keycode == KEY_I:
			$MainPanel.visible = !$MainPanel.visible
