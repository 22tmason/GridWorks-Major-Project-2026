extends CanvasLayer

var objective_label: Label

func _ready() -> void:
	layer = 10 
	_build_ui()
	_update_text()
	
	visible = false
	
	if get_node_or_null("/root/TutorialManager"):
		TutorialManager.step_changed.connect(_on_step_changed)
		TutorialManager.tutorial_finished.connect(_on_tutorial_finished)
	if SaveManager.pending_load:
		var tutorial = get_node_or_null("TutorialUI") 
		if tutorial:
			tutorial.visible = false
			
		SaveManager.pending_load = false
		SaveManager.call_deferred("load_game")

func _build_ui() -> void:
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	margin.offset_left = -420
	# --- FIXED: Shifted down to avoid overlapping the Space Elevator! ---
	margin.offset_top = 440 
	margin.offset_right = -24
	margin.offset_bottom = 580 
	add_child(margin)

	var panel = PanelContainer.new()
	margin.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10) 
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "📋 CURRENT OBJECTIVE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20) 
	vbox.add_child(title)

	var divider = HSeparator.new()
	vbox.add_child(divider)

	objective_label = Label.new()
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label.add_theme_font_size_override("font_size", 16) 
	vbox.add_child(objective_label)

func _on_step_changed(_step_idx: int, new_text: String) -> void:
	visible = true
	if objective_label:
		objective_label.text = new_text

func _on_tutorial_finished() -> void:
	visible = false

func _update_text() -> void:
	if get_node_or_null("/root/TutorialManager") and objective_label:
		objective_label.text = TutorialManager.get_current_objective()
