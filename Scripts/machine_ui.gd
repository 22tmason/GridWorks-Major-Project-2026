extends CanvasLayer

# 1. Grab your custom styled slot scene!
@export var slot_scene: PackedScene = preload("res://GridWorks Major Project 2026/Scenes/InventorySlot.tscn")

@onready var recipe_grid: GridContainer = $PanelContainer/VBoxContainer/RecipeGrid
@onready var title_label: Label = $PanelContainer/VBoxContainer/TitleLabel

var current_machine: Node2D = null

func _ready() -> void:
	visible = false

func open_ui(machine: Node2D) -> void:
	current_machine = machine
	visible = true
	
	# Clear out any old buttons
	for child in recipe_grid.get_children():
		child.queue_free()
		
	if not "recipes" in machine:
		return
		
	# Generate a custom slot for every recipe
	for recipe_id in machine.recipes.keys():
		var slot = slot_scene.instantiate()
		recipe_grid.add_child(slot)
		
		# USE THE NEW FUNCTION!
		slot.setup_display_slot(recipe_id)
		
		# Connect the custom slot's built-in button press
		slot.pressed.connect(func(): _on_recipe_selected(recipe_id))

func _on_recipe_selected(recipe_id: String) -> void:
	if current_machine and current_machine.has_method("set_active_recipe"):
		current_machine.set_active_recipe(recipe_id)
		
	visible = false
	current_machine = null

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_E:
			visible = false
			current_machine = null
			get_viewport().set_input_as_handled()
