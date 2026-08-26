extends Node

# Use load() instead of preload() to prevent circular dependency errors!
var straight_belt_mk1_scene = load("res://GridWorks Major Project 2026/Scenes/belt_mk1.tscn")
var straight_belt_mk2_scene = load("res://GridWorks Major Project 2026/Scenes/belt_mk2.tscn")
var straight_belt_mk3_scene = load("res://GridWorks Major Project 2026/Scenes/belt_mk3.tscn")
var corner_belt_right_mk1_scene = load("res://GridWorks Major Project 2026/Scenes/corner_belt_right_mk1.tscn")
var corner_belt_right_mk2_scene = load("res://GridWorks Major Project 2026/Scenes/corner_belt_right_mk2.tscn")
var corner_belt_right_mk3_scene = load("res://GridWorks Major Project 2026/Scenes/corner_belt_right_mk3.tscn")
var corner_belt_left_mk1_scene = load("res://GridWorks Major Project 2026/Scenes/corner_belt_left_mk1.tscn")
var corner_belt_left_mk2_scene = load("res://GridWorks Major Project 2026/Scenes/corner_belt_left_mk2.tscn")
var corner_belt_left_mk3_scene = load("res://GridWorks Major Project 2026/Scenes/corner_belt_left_mk3.tscn")
var inserter_scene = load("res://GridWorks Major Project 2026/Scenes/inserter.tscn")
var long_inserter_scene = load("res://GridWorks Major Project 2026/Scenes/long_inserter.tscn")
var underground_belt_mk1_scene = load("res://GridWorks Major Project 2026/Scenes/underground_belt_mk1.tscn")
var underground_belt_mk2_scene = load("res://GridWorks Major Project 2026/Scenes/underground_belt_mk2.tscn")
var underground_belt_mk3_scene = load("res://GridWorks Major Project 2026/Scenes/underground_belt_mk3.tscn")
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

var selected_scene: PackedScene = straight_belt_mk1_scene
var current_preview: Node2D = null

func change_building(new_scene: PackedScene, item_id: String = "") -> void:
	if item_id != "" and not ProgressionManager.is_unlocked(item_id):
		return

	selected_scene = new_scene
	
	if current_preview != null and is_instance_valid(current_preview):
		var preview_is_placed = false
		if "is_placed" in current_preview:
			preview_is_placed = current_preview.is_placed
			
		if not preview_is_placed:
			var parent = current_preview.get_parent()
			var current_pos = current_preview.global_position
			var current_rot = current_preview.rotation_degrees
			
			var current_dir = null
			if "current_direction" in current_preview:
				current_dir = current_preview.current_direction
			
			current_preview.queue_free()
			
			var new_preview = selected_scene.instantiate()
			new_preview.global_position = current_pos
			new_preview.rotation_degrees = current_rot
			
			if current_dir != null and "current_direction" in new_preview:
				new_preview.current_direction = current_dir
			
			parent.add_child(new_preview)
			current_preview = new_preview
	else:
		# If no preview exists, instantiate a new building preview into the scene
		var main_scene = get_tree().current_scene
		if main_scene and selected_scene:
			var new_preview = selected_scene.instantiate()
			main_scene.add_child(new_preview)
			current_preview = new_preview

func cancel_preview() -> void:
	if current_preview != null and is_instance_valid(current_preview):
		var preview_is_placed = false
		if "is_placed" in current_preview:
			preview_is_placed = current_preview.is_placed
			
		if not preview_is_placed:
			current_preview.queue_free()
			
	current_preview = null
