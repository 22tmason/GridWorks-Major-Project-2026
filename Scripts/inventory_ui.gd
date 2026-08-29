extends CanvasLayer

@export var slot_ui_scene: PackedScene = preload("res://GridWorks Major Project 2026/Scenes/InventorySlot.tscn")

@onready var main_panel = $MainPanel
@onready var inventory_grid = $MainPanel/HBoxContainer/LeftInventorySection/VBoxContainer/InventoryGrid

@onready var logistics_tab: VBoxContainer = $MainPanel/HBoxContainer/RightCraftingSection/VBoxContainer/TabContainer/Logistics
@onready var processing_tab: VBoxContainer = $MainPanel/HBoxContainer/RightCraftingSection/VBoxContainer/TabContainer/Processing
@onready var manufacturing_tab: VBoxContainer = $MainPanel/HBoxContainer/RightCraftingSection/VBoxContainer/TabContainer/Manufacturing
@onready var intermediates_tab: VBoxContainer = $MainPanel/HBoxContainer/RightCraftingSection/VBoxContainer/TabContainer/Intermediates
@onready var tab_container: TabContainer = $MainPanel/HBoxContainer/RightCraftingSection/VBoxContainer/TabContainer

@onready var craft_slider: HSlider = $MainPanel/HBoxContainer/RightCraftingSection/VBoxContainer/SliderContainer/CraftSlider
@onready var slider_label: Label = $MainPanel/HBoxContainer/RightCraftingSection/VBoxContainer/SliderContainer/SliderLabel

func _ready() -> void:
	InventoryManager.inventory_updated.connect(populate_ui_views)
	build_static_structure()
	populate_ui_views()
	
	if tab_container:
		tab_container.tab_changed.connect(_on_tab_changed)
		
	# --- NEW: Hook up the slider! ---
	if craft_slider:
		craft_slider.value_changed.connect(_on_slider_changed)
		_on_slider_changed(craft_slider.value) # Force an initial update
		
	visible = false

# --- NEW: Updates the global value and UI label ---
func _on_slider_changed(value: float) -> void:
	InventoryManager.craft_multiplier = int(value)
	if slider_label:
		slider_label.text = "Batch Size: " + str(int(value))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_Q:
			if BuildManager.current_preview != null:
				BuildManager.cancel_preview()
				get_viewport().set_input_as_handled()
				return
		
		if event.keycode == KEY_E:
			visible = not visible
			if visible:
				populate_ui_views()
			else:
				# --- FIXED: Only trigger the build cooldown when CLOSING the menu! ---
				BuildManager.notify_ui_closed() 
				
			# --- FIXED: Tell the TutorialManager the inventory was toggled! ---
			if get_node_or_null("/root/TutorialManager"):
				TutorialManager.notify_inventory_toggled(visible)
				
			get_viewport().set_input_as_handled()

func _on_tab_changed(tab_idx: int) -> void:
	var tab_names = ["logistics", "processing", "manufacturing", "intermediates"]
	if get_node_or_null("/root/TutorialManager") != null:
		TutorialManager.notify_tab_selected(tab_names[tab_idx])

func build_static_structure() -> void:
	for child in inventory_grid.get_children(): child.queue_free()
	_clear_tab(logistics_tab)
	_clear_tab(processing_tab)
	_clear_tab(manufacturing_tab)
	_clear_tab(intermediates_tab)
	
	for i in range(InventoryManager.INVENTORY_SIZE):
		var slot_instance = slot_ui_scene.instantiate()
		inventory_grid.add_child(slot_instance)
		
	var grouped_items = {
		"logistics": {}, "processing": {}, "manufacturing": {}, "intermediates": {}
	}
	
	for item_key in InventoryManager.item_database.keys():
		var item_data = InventoryManager.item_database[item_key]
		var cat = item_data.get("category", "logistics")
		var subcat = item_data.get("subcategory", "Misc")
		
		if not grouped_items.has(cat): continue
		
		if not grouped_items[cat].has(subcat):
			grouped_items[cat][subcat] = []
		grouped_items[cat][subcat].append(item_key)
		
	_build_tab_ui(logistics_tab, grouped_items["logistics"])
	_build_tab_ui(processing_tab, grouped_items["processing"])
	_build_tab_ui(manufacturing_tab, grouped_items["manufacturing"])
	_build_tab_ui(intermediates_tab, grouped_items["intermediates"])

func _clear_tab(tab_node: Control) -> void:
	for child in tab_node.get_children():
		child.queue_free()

func _build_tab_ui(tab_node: Control, subcategories: Dictionary) -> void:
	for subcat in subcategories.keys():
		var header_container = MarginContainer.new()
		header_container.add_theme_constant_override("margin_top", 12)
		header_container.add_theme_constant_override("margin_bottom", 8)
		
		var header_label = Label.new()
		header_label.text = "  " + subcat.to_upper() + "  "
		header_label.add_theme_font_size_override("font_size", 18) 
		header_label.add_theme_color_override("font_color", Color("b3b3b3ff"))
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color("262626ff")
		header_label.add_theme_stylebox_override("normal", style)
		
		header_container.add_child(header_label)
		tab_node.add_child(header_container)
		
		var grid = GridContainer.new()
		grid.columns = 6
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		tab_node.add_child(grid)
		
		for item_key in subcategories[subcat]:
			var craft_slot = slot_ui_scene.instantiate()
			grid.add_child(craft_slot)
			craft_slot.setup_crafting_slot(item_key)

func populate_ui_views() -> void:
	# 1. Update player inventory slot counts
	for i in range(InventoryManager.INVENTORY_SIZE):
		var slot_data = InventoryManager.slots[i]
		var ui_slot = inventory_grid.get_child(i)
		ui_slot.setup_inventory_slot(i, slot_data["id"], slot_data["quantity"])
		
	# 2. Refresh unlock status on all crafting tab slots
	_refresh_tab_slots(logistics_tab)
	_refresh_tab_slots(processing_tab)
	_refresh_tab_slots(manufacturing_tab)
	_refresh_tab_slots(intermediates_tab)

func _refresh_tab_slots(tab_node: Control) -> void:
	for child in tab_node.get_children():
		if child is GridContainer:
			for slot in child.get_children():
				if "current_item_id" in slot and slot.current_item_id != "":
					slot.setup_crafting_slot(slot.current_item_id)
