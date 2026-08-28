extends CanvasLayer

@onready var panel: PanelContainer = $PanelContainer
@onready var tabs_container: HBoxContainer = $PanelContainer/VBoxContainer/TimeTabs
@onready var graph_rect: ColorRect = $PanelContainer/VBoxContainer/GraphRect
@onready var list_container: GridContainer = $PanelContainer/VBoxContainer/ScrollContainer/ItemList
@onready var refresh_timer: Timer = $RefreshTimer

var intervals = {
	"5s": 5.0,
	"1m": 60.0,
	"10m": 600.0,
	"1h": 3600.0
}
var current_tab = "1m"
var tab_buttons = {}

func _ready() -> void:
	visible = false
	_apply_factorio_theme()
	
	refresh_timer.wait_time = 1.0 
	refresh_timer.timeout.connect(refresh_ui)
	
	# Dynamically build the Time Tabs
	for tab_name in intervals.keys():
		var btn = Button.new()
		btn.text = tab_name
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func(): _on_tab_pressed(tab_name))
		tabs_container.add_child(btn)
		tab_buttons[tab_name] = btn
		
	_update_tab_styles()

func _apply_factorio_theme() -> void:
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.18, 0.18, 0.18, 0.98) 
	panel_style.border_color = Color(0.33, 0.33, 0.33, 1.0)
	panel_style.set_border_width_all(6)
	panel_style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", panel_style)
	
	list_container.add_theme_constant_override("h_separation", 24)
	list_container.add_theme_constant_override("v_separation", 8)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_P and event.pressed and not event.echo:
		visible = not visible
		if visible:
			refresh_timer.start()
			refresh_ui()
		else:
			refresh_timer.stop()
			
		# --- NEW: Tell the TutorialManager! ---
		if get_node_or_null("/root/TutorialManager"):
			TutorialManager.notify_stats_toggled(visible)
			
		get_viewport().set_input_as_handled()

func _on_tab_pressed(tab_name: String) -> void:
	current_tab = tab_name
	_update_tab_styles()
	refresh_ui()

func _update_tab_styles() -> void:
	var active_style = StyleBoxFlat.new()
	active_style.bg_color = Color(0.9, 0.7, 0.2) # Factorio Yellow
	var inactive_style = StyleBoxFlat.new()
	inactive_style.bg_color = Color(0.4, 0.4, 0.4)
	
	for tab_name in tab_buttons:
		var btn = tab_buttons[tab_name]
		if tab_name == current_tab:
			btn.add_theme_stylebox_override("normal", active_style)
			btn.add_theme_color_override("font_color", Color.BLACK)
		else:
			btn.add_theme_stylebox_override("normal", inactive_style)
			btn.add_theme_color_override("font_color", Color.WHITE)

# Generates a unique, deterministic color based on the item's name
func _get_item_color(item_id: String) -> Color:
	var h = float(abs(item_id.hash()) % 1000) / 1000.0
	return Color.from_hsv(h, 0.8, 0.9)

func refresh_ui() -> void:
	for child in list_container.get_children():
		child.queue_free()
		
	var active_items = StatisticsManager.production_history.keys()
	var window_sec = intervals[current_tab]
	
	# Pre-calculate data so we can find the max value for the progress bars
	var item_stats = []
	var max_rate = 0.001
	
	graph_rect.graph_data.clear()
	graph_rect.item_colors.clear()
	
	for item_id in active_items:
		var count = StatisticsManager.get_production_count(item_id, window_sec)
		if count > 0:
			var rate_val = 0.0
			var rate_str = ""
			
			if window_sec <= 5.0:
				rate_val = float(count) / (window_sec / 60.0)
				rate_str = str(snapped(rate_val, 0.1)) + "/m"
			else:
				rate_val = float(count) / (window_sec / 60.0)
				rate_str = str(int(rate_val)) + "/m"
				
			if rate_val > max_rate: max_rate = rate_val
			
			var color = _get_item_color(item_id)
			item_stats.append({"id": item_id, "rate": rate_val, "str": rate_str, "color": color})
			
			graph_rect.graph_data[item_id] = StatisticsManager.get_graph_data(item_id, window_sec, 60)
			graph_rect.item_colors[item_id] = color
			
	# Redraw the line graph
	graph_rect.queue_redraw()
	
	# Build the 2-column Progress Bar list
	item_stats.sort_custom(func(a, b): return a.rate > b.rate)
	
	for stat in item_stats:
		var cell = HBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var icon = TextureRect.new()
		icon.texture = load(InventoryManager.item_database[stat.id]["texture"])
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		
		var progress = ProgressBar.new()
		progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		progress.custom_minimum_size = Vector2(0, 16)
		progress.max_value = max_rate
		progress.value = stat.rate
		progress.show_percentage = false
		
		var style_fill = StyleBoxFlat.new()
		style_fill.bg_color = stat.color
		var style_bg = StyleBoxFlat.new()
		style_bg.bg_color = Color(0.1, 0.1, 0.1)
		progress.add_theme_stylebox_override("fill", style_fill)
		progress.add_theme_stylebox_override("background", style_bg)
		
		var label = Label.new()
		label.text = stat.str
		label.custom_minimum_size = Vector2(55, 0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.add_theme_font_size_override("font_size", 14)
		
		cell.add_child(icon)
		cell.add_child(progress)
		cell.add_child(label)
		list_container.add_child(cell)
