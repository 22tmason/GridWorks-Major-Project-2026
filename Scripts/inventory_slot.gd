extends Button

@onready var icon_rect: TextureRect = $MarginContainer/Icon
@onready var count_label: Label = $CountLabel

var associated_slot_index: int = -1
var current_item_id: String = ""
var is_crafting_button: bool = false

func setup_inventory_slot(slot_idx: int, item_id: String, quantity: int) -> void:
	associated_slot_index = slot_idx
	current_item_id = item_id
	is_crafting_button = false
	
	if item_id == "" or quantity <= 0:
		icon_rect.texture = null
		count_label.text = ""
	else:
		var data = InventoryManager.item_database[item_id]
		icon_rect.texture = load(data["texture"])
		count_label.text = str(quantity)

func setup_crafting_slot(item_id: String) -> void:
	current_item_id = item_id
	is_crafting_button = true
	associated_slot_index = -1
	
	var data = InventoryManager.item_database[item_id]
	icon_rect.texture = load(data["texture"])
	count_label.text = "" # Free crafting uses no numeric counter text

func _pressed() -> void:
	if current_item_id == "":
		return
		
	if is_crafting_button:
		# Free crafting: Instantly create item out of thin air!
		InventoryManager.add_item(current_item_id, 1)
	else:
		# Inventory slot clicked: Load scene blueprint into the BuildManager
		var item_data = InventoryManager.item_database[current_item_id]
		var loaded_scene = load(item_data["scene"])
		BuildManager.change_building(loaded_scene)
		print("Equipped blueprint: ", item_data["name"])
