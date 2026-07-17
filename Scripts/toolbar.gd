extends CanvasLayer

func _ready() -> void:
	# Connect the buttons to our functions
	$HBoxContainer/StraightButton.pressed.connect(_on_straight_pressed)
	$HBoxContainer/CornerRightButton.pressed.connect(_on_corner_right_pressed)
	$HBoxContainer/CornerLeftButton.pressed.connect(_on_corner_left_pressed)
	$HBoxContainer/InserterButton.pressed.connect(_on_inserter_pressed)
	$HBoxContainer/LongInserterButton.pressed.connect(_on_long_inserter_pressed)
	$HBoxContainer/SplitterButton.pressed.connect(_on_splitter_pressed)
	$HBoxContainer/MergerButton.pressed.connect(_on_merger_pressed)
	$HBoxContainer/UndergroundButton.pressed.connect(_on_underground_pressed)
	$HBoxContainer/ElectricDrillButton.pressed.connect(_on_electric_drill_pressed)
	$HBoxContainer/StoneFurnaceButton.pressed.connect(_on_stone_furnace_pressed)

func _on_straight_pressed() -> void:
	BuildManager.change_building(BuildManager.straight_belt_scene)

func _on_corner_right_pressed() -> void:
	BuildManager.change_building(BuildManager.corner_belt_right_scene)
	
func _on_corner_left_pressed() -> void:
	BuildManager.change_building(BuildManager.corner_belt_left_scene)

func _on_inserter_pressed() -> void:
	BuildManager.change_building(BuildManager.inserter_scene)
	
func _on_long_inserter_pressed() -> void:
	BuildManager.change_building(BuildManager.long_inserter_scene)
	
func _on_splitter_pressed() -> void:
	BuildManager.change_building(BuildManager.splitter_scene)
	
func _on_merger_pressed() -> void:
	BuildManager.change_building(BuildManager.merger_scene)
	
func _on_underground_pressed() -> void:
	BuildManager.change_building(BuildManager.underground_belt_scene)
	
func _on_electric_drill_pressed() -> void:
	BuildManager.change_building(BuildManager.electric_drill_scene)
	
func _on_stone_furnace_pressed() -> void:
	BuildManager.change_building(BuildManager.stone_furnace_scene)
