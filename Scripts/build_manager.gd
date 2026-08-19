extends Node

# Load your scenes here (Make sure these exact paths are correct!)
var straight_belt_scene = preload("res://GridWorks Major Project 2026/Scenes/belt.tscn")
var corner_belt_right_scene = preload("res://GridWorks Major Project 2026/Scenes/corner_belt_right.tscn")
var corner_belt_left_scene = preload("res://GridWorks Major Project 2026/Scenes/corner_belt_left.tscn")
var inserter_scene = load("res://GridWorks Major Project 2026/Scenes/inserter.tscn")
var long_inserter_scene = load("res://GridWorks Major Project 2026/Scenes/long_inserter.tscn")
var splitter_scene = load("res://GridWorks Major Project 2026/Scenes/splitter.tscn")
var merger_scene = load("res://GridWorks Major Project 2026/Scenes/merger.tscn")
var underground_belt_scene = load("res://GridWorks Major Project 2026/Scenes/underground_belt.tscn")
var drill_mk1_scene = load("res://GridWorks Major Project 2026/Scenes/drill_mk1.tscn")
var drill_mk2_scene = load("res://GridWorks Major Project 2026/Scenes/drill_mk2.tscn")
var drill_mk3_scene = load("res://GridWorks Major Project 2026/Scenes/drill_mk3.tscn")
var furnace_mk1_scene = load("res://GridWorks Major Project 2026/Scenes/furnace_mk1.tscn")
var furnace_mk2_scene = load("res://GridWorks Major Project 2026/Scenes/furnace_mk2.tscn")
var furnace_mk3_scene = load("res://GridWorks Major Project 2026/Scenes/furnace_mk3.tscn")
var fast_inserter_scene = load("res://GridWorks Major Project 2026/Scenes/fast_inserter.tscn")
var processor_mk1_scene = load("res://GridWorks Major Project 2026/Scenes/processor_mk1.tscn")
var processor_mk2_scene = load("res://GridWorks Major Project 2026/Scenes/processor_mk2.tscn")
var processor_mk3_scene = load("res://GridWorks Major Project 2026/Scenes/processor_mk3.tscn")
var manufacturer_mk1_scene = load("res://GridWorks Major Project 2026/Scenes/manufacturer_mk1.tscn")
var manufacturer_mk2_scene = load("res://GridWorks Major Project 2026/Scenes/manufacturer_mk2.tscn")
var manufacturer_mk3_scene = load("res://GridWorks Major Project 2026/Scenes/manufacturer_mk3.tscn")

# Set the default building
@onready var selected_scene: PackedScene = straight_belt_scene

# This will keep track of the unplaced belt currently following your mouse
var current_preview: Node2D = null

func change_building(new_scene: PackedScene) -> void:
	selected_scene = new_scene
	
	if current_preview != null:
		# --- BULLETPROOF FIX: Safely check if it has is_placed ---
		var preview_is_placed = false
		if "is_placed" in current_preview:
			preview_is_placed = current_preview.is_placed
			
		# Only swap if the preview hasn't been permanently placed yet
		if not preview_is_placed:
			var parent = current_preview.get_parent()
			var current_pos = current_preview.global_position
			var current_rot = current_preview.rotation_degrees
			
			# Safely check for direction
			var current_dir = null
			if "current_direction" in current_preview:
				current_dir = current_preview.current_direction
			
			current_preview.queue_free()
			
			var new_preview = selected_scene.instantiate()
			new_preview.global_position = current_pos
			new_preview.rotation_degrees = current_rot
			
			# Safely apply direction if the new building supports it
			if current_dir != null and "current_direction" in new_preview:
				new_preview.current_direction = current_dir
			
			parent.add_child(new_preview)
			current_preview = new_preview
			# Add this to the very bottom of build_manager.gd

func cancel_preview() -> void:
	if current_preview != null:
		current_preview.queue_free()
		current_preview = null
