extends CanvasLayer

func _ready() -> void:
	# Connect the buttons to our functions
	$HBoxContainer/StraightButton.pressed.connect(_on_straight_pressed)
	$HBoxContainer/CornerButton.pressed.connect(_on_corner_pressed)

func _on_straight_pressed() -> void:
	BuildManager.change_building(BuildManager.straight_belt_scene)

func _on_corner_pressed() -> void:
	BuildManager.change_building(BuildManager.corner_belt_scene)
