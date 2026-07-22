extends CanvasLayer

signal start_tutorial_selected
signal skip_tutorial_selected

func _ready() -> void:
	# 1. CRITICAL: Allow UI input processing while the world is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	
	# 2. Automatically style and set up all UI nodes
	_apply_ui_styling()
	_connect_button_signals()

func _apply_ui_styling() -> void:
	# Set a dark overlay background
	var overlay = get_node_or_null("Overlay")
	if overlay and overlay is ColorRect:
		overlay.color = Color(0, 0, 0, 0.75) # Semi-transparent black tint
	
	# Give the main popup panel a solid minimum size
	var panel = _find_child_by_type(self, "PanelContainer")
	if panel:
		panel.custom_minimum_size = Vector2(620, 380)
	
	# Configure Title Label
	var title = _find_child_by_name(self, "TitleLabel") as Label
	if title:
		title.text = "WELCOME TO GRIDWORKS"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 24)

	# Configure Body Description Text
	var body = _find_child_by_type(self, "RichTextLabel") as RichTextLabel
	if body:
		body.custom_minimum_size = Vector2(560, 220)
		body.bbcode_enabled = true
		body.fit_content = false
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.text = (
			"[center][b]Build, Automate, and Expand Your Factory![/b][/center]\n\n" +
			"• [color=#e67e22][b]Harvest Raw Ore:[/b][/color] Set up drills and smelters to refine raw materials.\n" +
			"• [color=#3498db][b]Automate Logistics:[/b][/color] Place belts and inserters to route factory components.\n" +
			"• [color=#2ecc71][b]Manufacture Tech:[/b][/color] Supply processors to produce advanced components.\n\n" +
			"[center][i]Select how you would like to begin your game:[/i][/center]"
		)

	# Configure Buttons
	var start_btn = _find_child_by_name(self, "StartTutorialButton") as Button
	if start_btn:
		start_btn.text = "  Start Guided Tutorial  "
		start_btn.custom_minimum_size = Vector2(240, 50)
		start_btn.add_theme_font_size_override("font_size", 16)

	var skip_btn = _find_child_by_name(self, "SkipButton") as Button
	if skip_btn:
		skip_btn.text = "  Skip (Free Play)  "
		skip_btn.custom_minimum_size = Vector2(200, 50)
		skip_btn.add_theme_font_size_override("font_size", 16)

func _connect_button_signals() -> void:
	var start_btn = _find_child_by_name(self, "StartTutorialButton") as Button
	if start_btn and not start_btn.pressed.is_connected(_on_start_tutorial_pressed):
		start_btn.pressed.connect(_on_start_tutorial_pressed)
		
	var skip_btn = _find_child_by_name(self, "SkipButton") as Button
	if skip_btn and not skip_btn.pressed.is_connected(_on_skip_tutorial_pressed):
		skip_btn.pressed.connect(_on_skip_tutorial_pressed)

func _on_start_tutorial_pressed() -> void:
	get_tree().paused = false
	start_tutorial_selected.emit()
	
	if get_node_or_null("/root/TutorialManager"):
		TutorialManager.step_changed.emit(
			TutorialManager.current_step, 
			TutorialManager.get_current_objective()
		)
	
	queue_free() # Safely remove popup from memory & screen

func _on_skip_tutorial_pressed() -> void:
	get_tree().paused = false
	skip_tutorial_selected.emit()
	
	if get_node_or_null("/root/TutorialManager"):
		TutorialManager.current_step = TutorialManager.tutorial_steps.size()
		TutorialManager.tutorial_finished.emit()
		
	queue_free() # Safely remove popup from memory & screen

# --- HELPER FUNCTIONS (Prevents crash if scene hierarchy paths differ) ---
func _find_child_by_name(node: Node, child_name: String) -> Node:
	if node.name == child_name:
		return node
	for child in node.get_children():
		var found = _find_child_by_name(child, child_name)
		if found: return found
	return null

func _find_child_by_type(node: Node, type_name: String) -> Node:
	if node.get_class() == type_name:
		return node
	for child in node.get_children():
		var found = _find_child_by_type(child, type_name)
		if found: return found
	return null
