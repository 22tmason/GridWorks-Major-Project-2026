extends CanvasLayer

@export var slot_ui_scene: PackedScene = preload("res://GridWorks Major Project 2026/Scenes/InventorySlot.tscn")

@onready var main_panel = $MainPanel
@onready var inventory_grid = $MainPanel/HBoxContainer/LeftInventorySection/VBoxContainer/InventoryGrid

# These are now VBoxContainers (Make sure you changed them in the editor!)
@onready var logistics_tab: VBoxContainer = $MainPanel/HBoxContainer/RightCraftingSection/VBoxContainer/TabContainer/Logistics
@onready var processing_tab: VBoxContainer = $MainPanel/HBoxContainer/RightCraftingSection/VBoxContainer/TabContainer/Processing
@onready var manufacturing_tab: VBoxContainer = $MainPanel/HBoxContainer/RightCraftingSection/VBoxContainer/TabContainer/Manufacturing
@onready var intermediates_tab: VBoxContainer = $MainPanel/HBoxContainer/RightCraftingSection/VBoxContainer/TabContainer/Intermediates
@onready var tab_container: TabContainer = $MainPanel/HBoxContainer/RightCraftingSection/VBoxContainer/TabContainer

func _ready() -> void:
	InventoryManager.inventory_updated.connect(populate_ui_views)
	build_static_structure()
	populate_ui_views()
	
	if tab_container:
		tab_container.tab_changed.connect(_on_tab_changed)
		
	visible = false

# Listen for the 'E' key press to toggle the UI
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# Press Q to cancel building preview mode
		if event.keycode == KEY_Q:
			if BuildManager.current_preview != null:
				BuildManager.cancel_preview()
				get_viewport().set_input_as_handled()
				return
		
		# Press E to toggle inventory UI
		if event.keycode == KEY_E:
			visible = not visible
			if visible:
				populate_ui_views()
			get_viewport().set_input_as_handled()

func _on_tab_changed(tab_idx: int) -> void:
	var tab_names = ["logistics", "processing", "manufacturing", "intermediates"]
	if get_node_or_null("/root/TutorialManager") != null:
		TutorialManager.notify_tab_selected(tab_names[tab_idx])

func build_static_structure() -> void:
	# 1. Clear default mock items
	for child in inventory_grid.get_children(): child.queue_free()
	_clear_tab(logistics_tab)
	_clear_tab(processing_tab)
	_clear_tab(manufacturing_tab)
	_clear_tab(intermediates_tab)
	
	# 2. Build empty slots in the player inventory pane
	for i in range(InventoryManager.INVENTORY_SIZE):
		var slot_instance = slot_ui_scene.instantiate()
		inventory_grid.add_child(slot_instance)
		
	# 3. Group items by category and subcategory
	var grouped_items = {
		"logistics": {}, "processing": {}, "manufacturing": {}, "intermediates": {}
	}
	
	for item_key in InventoryManager.item_database.keys():
		var item_data = InventoryManager.item_database[item_key]
		var cat = item_data.get("category", "logistics")
		var subcat = item_data.get("subcategory", "Misc") # Defaults to "Misc" if you forget to add one
		
		if not grouped_items.has(cat): continue # Failsafe
		
		if not grouped_items[cat].has(subcat):
			grouped_items[cat][subcat] = []
		grouped_items[cat][subcat].append(item_key)
		
	# 4. Build the dynamic UI for each tab
	_build_tab_ui(logistics_tab, grouped_items["logistics"])
	_build_tab_ui(processing_tab, grouped_items["processing"])
	_build_tab_ui(manufacturing_tab, grouped_items["manufacturing"])
	_build_tab_ui(intermediates_tab, grouped_items["intermediates"])

# --- HELPER FUNCTIONS ---

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
		# INCREASED FONT SIZE HERE:
		header_label.add_theme_font_size_override("font_size", 18) 
		header_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.15, 0.15, 1)
		header_label.add_theme_stylebox_override("normal", style)
		
		header_container.add_child(header_label)
		tab_node.add_child(header_container)
		
		var grid = GridContainer.new()
		grid.columns = 6 # If the UI goes off-screen because icons are too big, drop this to 5
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		tab_node.add_child(grid)
		
		for item_key in subcategories[subcat]:
			var craft_slot = slot_ui_scene.instantiate()
			grid.add_child(craft_slot)
			craft_slot.setup_crafting_slot(item_key)

func populate_ui_views() -> void:
	# Update player inventory quantities (same as before)
	for i in range(InventoryManager.INVENTORY_SIZE):
		var slot_data = InventoryManager.slots[i]
		var ui_slot = inventory_grid.get_child(i)
		ui_slot.setup_inventory_slot(i, slot_data["id"], slot_data["quantity"])
