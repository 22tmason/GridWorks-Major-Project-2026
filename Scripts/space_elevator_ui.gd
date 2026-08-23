extends Control

@onready var phase_title_label: Label = $Panel/VBoxContainer/PhaseTitleLabel
@onready var item_container: VBoxContainer = $Panel/VBoxContainer/ItemContainer
@onready var seal_button: Button = $Panel/VBoxContainer/SealButton

var target_elevator: Node2D = null

func _ready() -> void:
	seal_button.pressed.connect(_on_seal_button_pressed)
	hide()

func open_ui(elevator: Node2D) -> void:
	# Unhook listeners from previously selected building if switching
	if target_elevator and is_instance_valid(target_elevator):
		if target_elevator.item_delivered.is_connected(_on_item_delivered):
			target_elevator.item_delivered.disconnect(_on_item_delivered)
		if target_elevator.phase_completed.is_connected(_on_phase_completed):
			target_elevator.phase_completed.disconnect(_on_phase_completed)

	target_elevator = elevator

	if target_elevator:
		target_elevator.item_delivered.connect(_on_item_delivered)
		target_elevator.phase_completed.connect(_on_phase_completed)
		refresh_ui()
		show()

func refresh_ui() -> void:
	if not target_elevator:
		return

	var current_phase: int = target_elevator.current_phase
	
	# Handle Game Completion State
	if current_phase >= target_elevator.phase_requirements.size():
		phase_title_label.text = "PROJECT ASSEMBLY COMPLETE"
		_clear_item_rows()
		seal_button.disabled = true
		seal_button.text = "Fully Upgraded"
		return

	phase_title_label.text = "Phase " + str(current_phase + 1) + " Delivery Progress"
	_clear_item_rows()

	var active_reqs: Dictionary = target_elevator.phase_requirements[current_phase]
	var active_deliveries: Dictionary = target_elevator.current_deliveries

	# Populate rows showing decreasing remaining amounts
	for item_id in active_reqs.keys():
		var total_required: int = active_reqs[item_id]
		var delivered: int = active_deliveries.get(item_id, 0)
		var remaining: int = max(0, total_required - delivered)

		var row = _build_item_row(item_id, remaining, total_required, delivered)
		item_container.add_child(row)

	# Enable Seal/Launch button only when all quantities reach 0 remaining
	seal_button.disabled = not target_elevator.is_phase_ready_to_seal()
	seal_button.text = "Seal Phase" if target_elevator.is_phase_ready_to_seal() else "Awaiting Resources"

func _build_item_row(item_id: String, remaining: int, total: int, delivered: int) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.name = item_id

	# Formatted item name and remaining count
	var label = Label.new()
	label.text = "%s: %d Remaining (%d/%d)" % [item_id.capitalize().replace("_", " "), remaining, delivered, total]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Visual Progress Bar
	var progress_bar = ProgressBar.new()
	progress_bar.max_value = total
	progress_bar.value = delivered
	progress_bar.custom_minimum_size = Vector2(140, 20)
	progress_bar.show_percentage = false

	row.add_child(label)
	row.add_child(progress_bar)
	return row

func _clear_item_rows() -> void:
	for child in item_container.get_children():
		child.queue_free()

func _on_item_delivered(_item_id: String, _current: int, _required: int) -> void:
	refresh_ui()

func _on_phase_completed(_phase_index: int) -> void:
	refresh_ui()

func _on_seal_button_pressed() -> void:
	if target_elevator and target_elevator.is_phase_ready_to_seal():
		target_elevator.seal_phase()
		refresh_ui()

func close_ui() -> void:
	hide()
