extends Node

# Load your scenes here (Make sure these exact paths are correct!)
var straight_belt_scene = preload("res://GridWorks Major Project 2026/Scenes/belt.tscn")
var corner_belt_scene = preload("res://GridWorks Major Project 2026/Scenes/corner_belt.tscn")
var inserter_scene = load("res://GridWorks Major Project 2026/Scenes/inserter.tscn")
var splitter_scene = load("res://GridWorks Major Project 2026/Scenes/Splitter.tscn")
var merger_scene = load("res://GridWorks Major Project 2026/Scenes/Merger.tscn")
var underground_belt_scene = load("res://GridWorks Major Project 2026/Scenes/underground_belt.tscn")

# Set the default building
@onready var selected_scene: PackedScene = straight_belt_scene

# This will keep track of the unplaced belt currently following your mouse
var current_preview: Node2D = null

func change_building(new_scene: PackedScene) -> void:
	selected_scene = new_scene
	
	if current_preview != null and not current_preview.is_placed:
		var parent = current_preview.get_parent()
		var current_pos = current_preview.global_position
		var current_rot = current_preview.rotation_degrees
		
		# --- NEW: Safely check for direction ---
		var current_dir = null
		if "current_direction" in current_preview:
			current_dir = current_preview.current_direction
		
		current_preview.queue_free()
		
		var new_preview = selected_scene.instantiate()
		new_preview.global_position = current_pos
		new_preview.rotation_degrees = current_rot
		
		# --- NEW: Safely apply direction if the new building supports it ---
		if current_dir != null and "current_direction" in new_preview:
			new_preview.current_direction = current_dir
		
		parent.add_child(new_preview)
		current_preview = new_preview
