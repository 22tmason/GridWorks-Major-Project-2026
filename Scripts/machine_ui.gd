extends CanvasLayer

@export var slot_scene: PackedScene = preload("res://GridWorks Major Project 2026/Scenes/InventorySlot.tscn")

# --- PROCESSOR PANEL MAIN REFERENCES ---
@onready var processor_panel: PanelContainer = $ProcessorPanel
@onready var left_panel: VBoxContainer = $ProcessorPanel/HBoxContainer/LeftPanel
@onready var scroll_container: ScrollContainer = $ProcessorPanel/HBoxContainer/LeftPanel/ScrollContainer
@onready var category_container: VBoxContainer = $ProcessorPanel/HBoxContainer/LeftPanel/ScrollContainer/CategoryContainer
@onready var title_label: Label = $ProcessorPanel/HBoxContainer/LeftPanel/TitleLabel

# --- RECIPE DETAILS PANEL REFERENCES ---
@onready var detail_icon: TextureRect = $ProcessorPanel/HBoxContainer/RightPanel/DetailsVBox/HeaderHBox/DetailIcon
@onready var detail_name: Label = $ProcessorPanel/HBoxContainer/RightPanel/DetailsVBox/HeaderHBox/DetailName
@onready var detail_description: Label = $ProcessorPanel/HBoxContainer/RightPanel/DetailsVBox/DetailDescription
@onready var detail_time_label: Label = $ProcessorPanel/HBoxContainer/RightPanel/DetailsVBox/DetailTimeLabel
@onready var inputs_hbox: HBoxContainer = $ProcessorPanel/HBoxContainer/RightPanel/DetailsVBox/InputsHBox
@onready var outputs_hbox: HBoxContainer = $ProcessorPanel/HBoxContainer/RightPanel/DetailsVBox/OutputsHBox
@onready var confirm_button: Button = $ProcessorPanel/HBoxContainer/RightPanel/DetailsVBox/ConfirmButton

# --- SPACE ELEVATOR UI REFERENCES ---
@onready var elevator_panel: PanelContainer = $ElevatorPanel
@onready var phase_title_label: Label = $ElevatorPanel/VBoxContainer/PhaseTitleLabel
@onready var item_container: VBoxContainer = $ElevatorPanel/VBoxContainer/ItemContainer
@onready var seal_button: Button = $ElevatorPanel/VBoxContainer/SealButton

var current_machine: Node2D = null
var selected_recipe_id: String = ""

func _ready() -> void:
	visible = false
	_apply_ui_theme()
	
	if seal_button:
		seal_button.pressed.connect(_on_seal_button_pressed)
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_recipe_pressed)

# --- THEME & LAYOUT STYLING ---
func _apply_ui_theme() -> void:
	# Main Panel Dark Styling
	var dark_panel_style = StyleBoxFlat.new()
	dark_panel_style.bg_color = Color(0.145, 0.145, 0.145, 0.98)
	dark_panel_style.border_color = Color(0.333, 0.333, 0.333, 1.0)
	dark_panel_style.set_border_width_all(6)
	dark_panel_style.set_content_margin_all(16.0)

	processor_panel.add_theme_stylebox_override("panel", dark_panel_style)
	elevator_panel.add_theme_stylebox_override("panel", dark_panel_style)

	var sub_panel_style = StyleBoxFlat.new()
	sub_panel_style.bg_color = Color(0.1, 0.1, 0.1, 0.6)
	sub_panel_style.border_color = Color(0.25, 0.25, 0.25, 0.8)
	sub_panel_style.set_border_width_all(2)
	sub_panel_style.set_content_margin_all(12.0)
	$ProcessorPanel/HBoxContainer/RightPanel.add_theme_stylebox_override("panel", sub_panel_style)

	# --- HEADER PROMINENCE STYLING ---
	# Left Title Header ("Select Recipe")
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))

	# Right Item Title Header ("Copper Wire")
	detail_name.add_theme_font_size_override("font_size", 22)
	detail_name.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35)) # Warm Gold Highlight
	detail_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	detail_icon.custom_minimum_size = Vector2(56, 56)

	# Section Headers ("INPUTS", "OUTPUT")
	var inputs_label = $ProcessorPanel/HBoxContainer/RightPanel/DetailsVBox/InputsLabel
	var outputs_label = $ProcessorPanel/HBoxContainer/RightPanel/DetailsVBox/OutputsLabel
	if inputs_label:
		inputs_label.add_theme_font_size_override("font_size", 13)
		inputs_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	if outputs_label:
		outputs_label.add_theme_font_size_override("font_size", 13)
		outputs_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

	# Container Expansion Rules
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	category_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_style_button(seal_button)
	_style_button(confirm_button)

func _style_button(btn: Button) -> void:
	if not btn: return
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.2, 0.2, 0.2, 1.0)
	normal.border_color = Color(0.4, 0.4, 0.4, 1.0)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(4)

	var hover = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.28, 0.28, 0.28, 1.0)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.custom_minimum_size = Vector2(0, 40)

func open_ui(machine: Node2D) -> void:
	_disconnect_machine_signals()
	current_machine = machine
	visible = true

	if "phase_requirements" in machine:
		processor_panel.visible = false
		elevator_panel.visible = true
		_connect_machine_signals()
		_refresh_elevator_ui()
	elif "recipes" in machine:
		elevator_panel.visible = false
		processor_panel.visible = true
		_setup_processor_ui()
	else:
		close_ui()

func close_ui() -> void:
	_disconnect_machine_signals()
	visible = false
	current_machine = null
	selected_recipe_id = ""

# --- CATEGORIZED PROCESSOR LOGIC ---
func _setup_processor_ui() -> void:
	for child in category_container.get_children():
		child.queue_free()

	if not current_machine or not "recipes" in current_machine:
		return

	# Group recipes by subcategory using InventoryManager
	var grouped_recipes: Dictionary = {}
	for recipe_id in current_machine.recipes.keys():
		var subcat = "UNCATEGORIZED"
		if InventoryManager.item_database.has(recipe_id):
			subcat = InventoryManager.item_database[recipe_id].get("subcategory", "UNCATEGORIZED").to_upper()
		
		if not grouped_recipes.has(subcat):
			grouped_recipes[subcat] = []
		grouped_recipes[subcat].append(recipe_id)

	# Build category sections with GridContainers
	for subcat_name in grouped_recipes.keys():
		var header = Label.new()
		header.text = subcat_name
		header.add_theme_font_size_override("font_size", 12)
		header.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
		category_container.add_child(header)

		var grid = GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		category_container.add_child(grid)

		for recipe_id in grouped_recipes[subcat_name]:
			var slot = slot_scene.instantiate()
			grid.add_child(slot)
			slot.setup_display_slot(recipe_id)
			slot.pressed.connect(func(): _display_recipe_details(recipe_id))

	# Select current machine recipe or first available
	var default_recipe = current_machine.selected_recipe if current_machine.selected_recipe != "" else current_machine.recipes.keys()[0]
	_display_recipe_details(default_recipe)

# --- RECIPE DETAILS PANEL ---
func _display_recipe_details(recipe_id: String) -> void:
	selected_recipe_id = recipe_id
	if not InventoryManager.item_database.has(recipe_id): return

	var item_data = InventoryManager.item_database[recipe_id]
	detail_name.text = item_data.get("name", recipe_id.capitalize())
	detail_description.text = item_data.get("description", "")
	detail_icon.texture = load(item_data["texture"])

	var craft_time = current_machine.recipe_times.get(recipe_id, current_machine.processing_time) if "recipe_times" in current_machine else current_machine.processing_time
	detail_time_label.text = "Craft Time: %.1fs" % craft_time

	# Clear and rebuild Inputs
	for child in inputs_hbox.get_children(): child.queue_free()
	var reqs = current_machine.recipe_requirements.get(recipe_id, {}) if "recipe_requirements" in current_machine else {}
	
	for input_id in reqs.keys():
		var amount = reqs[input_id]
		var slot = slot_scene.instantiate()
		inputs_hbox.add_child(slot)
		slot.setup_display_slot(input_id)
		slot.count_label.text = str(amount)

	# Clear and rebuild Output
	for child in outputs_hbox.get_children(): child.queue_free()
	var out_slot = slot_scene.instantiate()
	outputs_hbox.add_child(out_slot)
	out_slot.setup_display_slot(recipe_id)
	out_slot.count_label.text = "1"

func _on_confirm_recipe_pressed() -> void:
	if current_machine and selected_recipe_id != "" and current_machine.has_method("set_active_recipe"):
		current_machine.set_active_recipe(selected_recipe_id)
		close_ui()

# --- SPACE ELEVATOR LOGIC ---
func _connect_machine_signals() -> void:
	if not current_machine: return
	if current_machine.has_signal("item_delivered") and not current_machine.item_delivered.is_connected(_on_elevator_updated):
		current_machine.item_delivered.connect(_on_elevator_updated)
	if current_machine.has_signal("phase_completed") and not current_machine.phase_completed.is_connected(_on_elevator_updated):
		current_machine.phase_completed.connect(_on_elevator_updated)

func _disconnect_machine_signals() -> void:
	if not current_machine: return
	if current_machine.has_signal("item_delivered") and current_machine.item_delivered.is_connected(_on_elevator_updated):
		current_machine.item_delivered.disconnect(_on_elevator_updated)
	if current_machine.has_signal("phase_completed") and current_machine.phase_completed.is_connected(_on_elevator_updated):
		current_machine.phase_completed.disconnect(_on_elevator_updated)

func _on_elevator_updated(_arg1 = null, _arg2 = null, _arg3 = null) -> void:
	if visible and elevator_panel.visible:
		_refresh_elevator_ui()

func _refresh_elevator_ui() -> void:
	if not current_machine: return

	var current_phase: int = current_machine.current_phase
	if current_phase >= current_machine.phase_requirements.size():
		phase_title_label.text = "PROJECT ASSEMBLY COMPLETE"
		_clear_item_rows()
		seal_button.disabled = true
		seal_button.text = "Fully Upgraded"
		return

	phase_title_label.text = "Phase " + str(current_phase + 1) + " Delivery Progress"
	_clear_item_rows()

	var active_reqs: Dictionary = current_machine.phase_requirements[current_phase]
	var active_deliveries: Dictionary = current_machine.current_deliveries

	for item_id in active_reqs.keys():
		var total_required: int = active_reqs[item_id]
		var delivered: int = active_deliveries.get(item_id, 0)
		var remaining: int = max(0, total_required - delivered)

		var row = _build_item_row(item_id, remaining, total_required, delivered)
		item_container.add_child(row)

	var is_ready = current_machine.is_phase_ready_to_seal()
	seal_button.disabled = not is_ready
	seal_button.text = "Seal Phase" if is_ready else "Awaiting Resources"

func _build_item_row(item_id: String, remaining: int, total: int, delivered: int) -> PanelContainer:
	var row_panel = PanelContainer.new()
	var row_style = StyleBoxFlat.new()
	row_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	row_style.set_content_margin_all(8.0)
	row_panel.add_theme_stylebox_override("panel", row_style)

	var hbox = HBoxContainer.new()
	var label = Label.new()
	label.text = "%s\n%d Remaining (%d/%d)" % [item_id.capitalize().replace("_", " "), remaining, delivered, total]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 14)

	var progress_bar = ProgressBar.new()
	progress_bar.max_value = total
	progress_bar.value = delivered
	progress_bar.custom_minimum_size = Vector2(180, 24)
	progress_bar.show_percentage = false

	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.05, 0.05, 0.05, 1.0)
	bar_bg.border_color = Color(0.25, 0.25, 0.25, 1.0)
	bar_bg.set_border_width_all(1)

	var bar_fill = StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.85, 0.55, 0.15, 1.0) if delivered < total else Color(0.2, 0.7, 0.3, 1.0)

	progress_bar.add_theme_stylebox_override("background", bar_bg)
	progress_bar.add_theme_stylebox_override("fill", bar_fill)

	hbox.add_child(label)
	hbox.add_child(progress_bar)
	row_panel.add_child(hbox)
	return row_panel

func _clear_item_rows() -> void:
	for child in item_container.get_children():
		child.queue_free()

func _on_seal_button_pressed() -> void:
	if current_machine and current_machine.has_method("seal_phase") and current_machine.is_phase_ready_to_seal():
		current_machine.seal_phase()
		_refresh_elevator_ui()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_E:
			close_ui()
			get_viewport().set_input_as_handled()
