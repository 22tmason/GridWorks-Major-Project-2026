extends CanvasLayer

@onready var panel: PanelContainer = $PanelContainer
@onready var vbox: VBoxContainer = $PanelContainer/VBoxContainer
@onready var music_slider: HSlider = $PanelContainer/VBoxContainer/MusicSlider
@onready var sfx_slider: HSlider = $PanelContainer/VBoxContainer/SFXSlider
@onready var close_button: Button = $PanelContainer/VBoxContainer/CloseButton

var parent_menu: Node = null

func _ready() -> void:
	# 1. Allow this menu to process input even when the game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_apply_factorio_theme()
	
	music_slider.min_value = 0.0001 
	music_slider.max_value = 1.0
	music_slider.step = 0.05
	
	sfx_slider.min_value = 0.0001
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.05
	
	# 2. Lock sliders to the actual AudioManager memory!
	music_slider.value = AudioManager.current_music_volume
	sfx_slider.value = AudioManager.current_sfx_volume
	
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	sfx_slider.drag_ended.connect(_on_sfx_drag_ended)
	close_button.pressed.connect(_on_close_pressed)

func _on_music_changed(value: float) -> void:
	AudioManager.set_music_volume(value)

func _on_sfx_changed(value: float) -> void:
	AudioManager.set_sfx_volume(value)
	
func _on_sfx_drag_ended(_value_changed: bool) -> void:
	AudioManager.play_sound(AudioManager.click_sound)

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

	close_button.add_theme_stylebox_override("normal", btn_normal)
	close_button.add_theme_stylebox_override("hover", btn_hover)
	close_button.add_theme_stylebox_override("pressed", btn_normal)
	close_button.add_theme_font_size_override("font_size", 24)
	close_button.add_theme_color_override("font_color", Color.BLACK)
	close_button.add_theme_color_override("font_hover_color", Color.BLACK)
	close_button.add_theme_color_override("font_pressed_color", Color.BLACK)

func _on_close_pressed() -> void:
	# Instantly write settings to disk when confirming!
	AudioManager.save_settings()
	
	if parent_menu and "panel" in parent_menu:
		parent_menu.panel.visible = true
	queue_free()
