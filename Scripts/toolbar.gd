extends CanvasLayer

func _ready() -> void:
	# Connect the buttons to our functions
	$HBoxContainer/StraightButton.pressed.connect(_on_straight_pressed)
	$HBoxContainer/CornerButton.pressed.connect(_on_corner_pressed)
	
	# --- NEW: Connect the Inserter button ---
	$HBoxContainer/InserterButton.pressed.connect(_on_inserter_pressed) # Ensure "InserterButton" matches your actual node name!

func _on_straight_pressed() -> void:
	BuildManager.change_building(BuildManager.straight_belt_scene)

func _on_corner_pressed() -> void:
	BuildManager.change_building(BuildManager.corner_belt_scene)

# --- NEW: Function to change to the Inserter ---
func _on_inserter_pressed() -> void:
	BuildManager.change_building(BuildManager.inserter_scene)
