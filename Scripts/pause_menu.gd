extends CanvasLayer

@onready var panel: PanelContainer = $ColorRect/PanelContainer 
@onready var vbox: VBoxContainer = $ColorRect/PanelContainer/VBoxContainer

@onready var resume_button: Button = $ColorRect/PanelContainer/VBoxContainer/ResumeButton
@onready var save_button: Button = $ColorRect/PanelContainer/VBoxContainer/SaveButton 
@onready var menu_button: Button = $ColorRect/PanelContainer/VBoxContainer/MenuButton

func _ready() -> void:
	# This hides the invisible blocking rectangle!
	visible = false
	
	_apply_factorio_theme()
	
	resume_button.pressed.connect(_on_resume_pressed)
	save_button.pressed.connect(_on_save_pressed)
	menu_button.pressed.connect(_on_menu_pressed)

func _apply_factorio_theme() -> void:
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.2, 0.2, 0.2, 1.0) 
	panel_style.border_color = Color(0.1, 0.1, 0.1, 1.0)
	panel_style.set_border_width_all(4)
	panel_style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", panel_style)
	
	vbox.custom_minimum_size = Vector2(400, 0)
	vbox.add_theme_constant_override("separation", 12)
	
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.55, 0.55, 0.55, 1.0)
	btn_normal.border_color = Color(0.15, 0.15, 0.15, 1.0)
	btn_normal.set_border_width_all(4)
	btn_normal.set_content_margin_all(12)
	
	var btn_hover = btn_normal.duplicate()
	btn_hover.bg_color = Color(0.65, 0.65, 0.65, 1.0)

	var resume_normal = btn_normal.duplicate()
	resume_normal.bg_color = Color(0.45, 0.75, 0.45, 1.0)
	var resume_hover = resume_normal.duplicate()
	resume_hover.bg_color = Color(0.55, 0.85, 0.55, 1.0)
	_style_button(resume_button, resume_normal, resume_hover)
	resume_button.text = "Resume Game"
	
	_style_button(save_button, btn_normal, btn_hover)
	save_button.text = "Save Game"

	var quit_normal = btn_normal.duplicate()
	quit_normal.bg_color = Color(0.9, 0.4, 0.4, 1.0)
	var quit_hover = quit_normal.duplicate()
	quit_hover.bg_color = Color(1.0, 0.5, 0.5, 1.0)
	
	_style_button(menu_button, quit_normal, quit_hover)
	menu_button.text = "Main Menu"
	menu_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	menu_button.custom_minimum_size = Vector2(400, 0)

func _style_button(btn: Button, normal: StyleBox, hover: StyleBox) -> void:
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", normal)
	
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", Color.BLACK)
	btn.add_theme_color_override("font_hover_color", Color.BLACK)
	btn.add_theme_color_override("font_pressed_color", Color.BLACK)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		toggle_pause()
		get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	var new_pause_state = not get_tree().paused
	get_tree().paused = new_pause_state
	visible = new_pause_state
	
	if new_pause_state:
		var inv_ui = get_tree().current_scene.get_node_or_null("InventoryUI")
		if inv_ui: inv_ui.visible = false
		
		var machine_ui = get_tree().get_first_node_in_group("machine_ui")
		if machine_ui: machine_ui.close_ui()

func _on_resume_pressed() -> void:
	toggle_pause()
	
func _on_save_pressed() -> void:
	SaveManager.save_game()

func _on_menu_pressed() -> void:
	get_tree().paused = false 
	get_tree().change_scene_to_file("res://GridWorks Major Project 2026/Scenes/main_menu.tscn")
