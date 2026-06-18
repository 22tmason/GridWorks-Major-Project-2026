extends CanvasLayer

func _ready() -> void:
	# Connect the buttons to our functions
	$HBoxContainer/StraightButton.pressed.connect(_on_straight_pressed)
	$HBoxContainer/CornerButton.pressed.connect(_on_corner_pressed)
	$HBoxContainer/InserterButton.pressed.connect(_on_inserter_pressed)
	$HBoxContainer/SplitterButton.pressed.connect(_on_splitter_pressed)
	$HBoxContainer/MergerButton.pressed.connect(_on_merger_pressed)
	$HBoxContainer/UndergroundButton.pressed.connect(_on_underground_pressed)
	

func _on_straight_pressed() -> void:
	BuildManager.change_building(BuildManager.straight_belt_scene)

func _on_corner_pressed() -> void:
	BuildManager.change_building(BuildManager.corner_belt_scene)

func _on_inserter_pressed() -> void:
	BuildManager.change_building(BuildManager.inserter_scene)
	
func _on_splitter_pressed() -> void:
	BuildManager.change_building(BuildManager.splitter_scene)
	
func _on_merger_pressed() -> void:
	BuildManager.change_building(BuildManager.merger_scene)
	
func _on_underground_pressed() -> void:
	BuildManager.change_building(BuildManager.underground_belt_scene)
