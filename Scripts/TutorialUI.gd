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
	# 1. INCREASED WIDTTH AND HEIGHT OF THE BOX
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	margin.offset_left = -420 # Made wider (was -340)
	margin.offset_top = 24
	margin.offset_right = -24
	margin.offset_bottom = 160 # Made taller (was 120)
	add_child(margin)

	var panel = PanelContainer.new()
	margin.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10) # More breathing room
	panel.add_child(vbox)

	# 2. INCREASED HEADER FONT SIZE
	var title = Label.new()
	title.text = "📋 CURRENT OBJECTIVE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20) # Made text larger
	vbox.add_child(title)

	var divider = HSeparator.new()
	vbox.add_child(divider)

	# 3. INCREASED OBJECTIVE TEXT FONT SIZE
	objective_label = Label.new()
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label.add_theme_font_size_override("font_size", 16) # Made text larger
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
