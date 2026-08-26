extends Control

# Note: We added a PanelContainer wrapper in the editor steps!
@onready var panel: PanelContainer = $PanelContainer 
@onready var vbox: VBoxContainer = $PanelContainer/VBoxContainer

@onready var play_button: Button = $PanelContainer/VBoxContainer/PlayButton
@onready var load_button: Button = $PanelContainer/VBoxContainer/LoadButton
@onready var quit_button: Button = $PanelContainer/VBoxContainer/QuitButton

func _ready() -> void:
	get_tree().paused = false
	
	_apply_factorio_theme()

	play_button.pressed.connect(_on_play_pressed)
	load_button.pressed.connect(_on_load_pressed) 
	quit_button.pressed.connect(_on_quit_pressed)

func _apply_factorio_theme() -> void:
	# 1. Style the Main Background Box
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.2, 0.2, 0.2, 1.0) # Dark grey background
	panel_style.border_color = Color(0.1, 0.1, 0.1, 1.0)
	panel_style.set_border_width_all(4)
	panel_style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", panel_style)
	
	# Widen the menu and space out buttons
	vbox.custom_minimum_size = Vector2(400, 0)
	vbox.add_theme_constant_override("separation", 12)
	
	# 2. Create Base Button Style (Factorio Gray)
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.55, 0.55, 0.55, 1.0)
	btn_normal.border_color = Color(0.15, 0.15, 0.15, 1.0)
	btn_normal.set_border_width_all(4)
	btn_normal.set_content_margin_all(12)
	
	var btn_hover = btn_normal.duplicate()
	btn_hover.bg_color = Color(0.65, 0.65, 0.65, 1.0) # Brighter on hover

	# 3. Apply to Play Button (Standard Gray)
	_style_button(play_button, btn_normal, btn_hover)
	play_button.text = "New Game"
	
	# 4. Apply to Load Button (Factorio Green)
	var load_normal = btn_normal.duplicate()
	load_normal.bg_color = Color(0.45, 0.75, 0.45, 1.0)
	var load_hover = load_normal.duplicate()
	load_hover.bg_color = Color(0.55, 0.85, 0.55, 1.0)
	_style_button(load_button, load_normal, load_hover)
	load_button.text = "Continue Game"

	# 5. Apply to Quit Button (Factorio Red)
	var quit_normal = btn_normal.duplicate()
	quit_normal.bg_color = Color(0.9, 0.4, 0.4, 1.0)
	var quit_hover = quit_normal.duplicate()
	quit_hover.bg_color = Color(1.0, 0.5, 0.5, 1.0)
	
	_style_button(quit_button, quit_normal, quit_hover)
	quit_button.text = "Exit"
	# Make the quit button smaller and left-aligned like Factorio
	quit_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	quit_button.custom_minimum_size = Vector2(400, 0)

# Helper function to apply font colors and styleboxes
func _style_button(btn: Button, normal: StyleBox, hover: StyleBox) -> void:
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", normal)
	
	# Factorio text is bold, black, and large
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", Color.BLACK)
	btn.add_theme_color_override("font_hover_color", Color.BLACK)
	btn.add_theme_color_override("font_pressed_color", Color.BLACK)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://GridWorks Major Project 2026/Scenes/main_level.tscn")

func _on_load_pressed() -> void:
	# Tell the SaveManager we want to load, then change the scene normally
	SaveManager.pending_load = true
	get_tree().change_scene_to_file("res://GridWorks Major Project 2026/Scenes/main_level.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
