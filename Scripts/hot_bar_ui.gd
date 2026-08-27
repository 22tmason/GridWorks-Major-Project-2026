extends CanvasLayer

@export var slot_scene: PackedScene = preload("res://GridWorks Major Project 2026/Scenes/InventorySlot.tscn")
@onready var hotbar_box: HBoxContainer = $MarginContainer/PanelContainer/HotbarBox

func _ready() -> void:
	# Listen for when the player binds a new item so we can redraw
	InventoryManager.hotbar_updated.connect(_build_hotbar)
	_build_hotbar()

func _build_hotbar() -> void:
	# 1. Clear any old slots first (important for when we redraw)
	for child in hotbar_box.get_children():
		child.queue_free()

	# 2. Always generate exactly 9 slots
	for i in range(9):
		var item_id = InventoryManager.hotbar_items[i]
		var slot = slot_scene.instantiate()
		hotbar_box.add_child(slot)
		
		var icon = slot.get_node("MarginContainer/Icon")
		var label = slot.get_node("CountLabel")
		
		# Format the hotkey number
		label.text = str(i + 1) 
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", Color(1, 0.8, 0)) # Gold tint
		
		# If the slot has an item, show it!
		if item_id != "" and InventoryManager.item_database.has(item_id):
			var item_data = InventoryManager.item_database[item_id]
			icon.texture = load(item_data["texture"])
			slot.tooltip_text = item_data["name"] + "\n(Hotkey: " + str(i + 1) + ")"
			slot.pressed.connect(func(): _select_hotbar_item(item_id))
		# If the slot is empty, make it a blank box
		else:
			icon.texture = null
			slot.tooltip_text = "Empty Slot\n(Hover an item in inventory and press " + str(i + 1) + " to bind)"

func _unhandled_input(event: InputEvent) -> void:
	for i in range(9):
		var keycode = KEY_1 + i
		if event is InputEventKey and event.keycode == keycode and event.pressed:
			
			# IF HOVERING: Bind the hovered item to this slot
			if InventoryManager.hovered_item_id != "":
				InventoryManager.set_hotbar_item(i, InventoryManager.hovered_item_id)
				
			# IF NOT HOVERING: Equip the item in this slot to the mouse
			else:
				var item_id = InventoryManager.hotbar_items[i]
				if item_id != "":
					_select_hotbar_item(item_id)
					
			get_viewport().set_input_as_handled()

func _select_hotbar_item(item_id: String) -> void:
	if not ProgressionManager.is_unlocked(item_id):
		return
		
	var item_data = InventoryManager.item_database.get(item_id)
	if not item_data or not item_data.has("scene"):
		return
		
	# --- FIX: Route hotbar selection through BuildManager so it remembers the Item ID! ---
	var scene_path = item_data["scene"]
	var loaded_scene = load(scene_path)
	BuildManager.change_building(loaded_scene, item_id)
