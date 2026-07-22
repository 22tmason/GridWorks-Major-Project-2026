extends CanvasLayer

var objective_label: Label

func _ready() -> void:
	layer = 10 # Ensures it displays on top of other UI elements
	_build_ui()
	_update_text()
	
	# 1. Hide the objective box immediately at launch
	visible = false
	
	if get_node_or_null("/root/TutorialManager"):
		TutorialManager.step_changed.connect(_on_step_changed)
		TutorialManager.tutorial_finished.connect(_on_tutorial_finished)

func _build_ui() -> void:
	# Create margin container aligned to top-right
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	margin.offset_left = -340
	margin.offset_top = 20
	margin.offset_right = -20
	margin.offset_bottom = 120
	add_child(margin)

	# Panel container for dark background card
	var panel = PanelContainer.new()
	margin.add_child(panel)

	# Vertical stack container
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# Header title
	var title = Label.new()
	title.text = "📋 CURRENT OBJECTIVE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var divider = HSeparator.new()
	vbox.add_child(divider)

	# Objective text display
	objective_label = Label.new()
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(objective_label)

func _on_step_changed(_step_idx: int, new_text: String) -> void:
	# 2. Show the box as soon as the player clicks "Start Guided Tutorial"
	visible = true
	if objective_label:
		objective_label.text = new_text

func _on_tutorial_finished() -> void:
	# 3. Keep hidden if skipped or finished
	visible = false

func _update_text() -> void:
	if get_node_or_null("/root/TutorialManager") and objective_label:
		objective_label.text = TutorialManager.get_current_objective()
