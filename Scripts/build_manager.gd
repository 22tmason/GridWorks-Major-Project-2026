extends Node

# Load your scenes here (Make sure these exact paths are correct!)
var straight_belt_scene = preload("res://GridWorks Major Project 2026/Scenes/belt.tscn")
var corner_belt_scene = preload("res://GridWorks Major Project 2026/Scenes/corner_belt.tscn")

# Set the default building
@onready var selected_scene: PackedScene = straight_belt_scene

# This will keep track of the unplaced belt currently following your mouse
var current_preview: Node2D = null

func change_building(new_scene: PackedScene) -> void:
	selected_scene = new_scene
	
	# If we are currently holding a preview, we need to destroy it and spawn the new one
	if current_preview != null and not current_preview.is_placed:
		var parent = current_preview.get_parent()
		var current_pos = current_preview.global_position
		var current_rot = current_preview.rotation_degrees
		var current_dir = current_preview.current_direction
		
		# Delete the old preview
		current_preview.queue_free()
		
		# Spawn the new preview
		var new_preview = selected_scene.instantiate()
		new_preview.global_position = current_pos
		new_preview.rotation_degrees = current_rot
		new_preview.current_direction = current_dir
		
		parent.add_child(new_preview)
		current_preview = new_preview
