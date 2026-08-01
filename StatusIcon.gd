extends Sprite2D
class_name StatusIcon

enum Status {
	WORKING,
	NO_INPUT,
	OUTPUT_FULL,
	NO_RECIPE
}

@export var icon_no_input: Texture2D
@export var icon_output_full: Texture2D
@export var icon_no_recipe: Texture2D

var current_status: Status = Status.WORKING
var animation_timer: float = 0.0

# Store where you dragged the icon in the editor (e.g., directly above the building)
var editor_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	editor_offset = position # Capture your custom placement
	top_level = true         # CRITICAL: Detach from parent transforms completely
	visible = false

func _process(delta: float) -> void:
	if visible:
		# 1. Calculate the up-and-down global wobble
		animation_timer += delta * 4.0
		var wobble_offset = Vector2(0, sin(animation_timer) * 3.0)
		
		# 2. Lock position to the parent globally, ignoring its rotation entirely
		var parent = get_parent()
		if parent and parent is Node2D:
			global_position = parent.global_position + editor_offset + wobble_offset

func set_status(new_status: Status) -> void:
	if current_status == new_status:
		return
		
	current_status = new_status
	
	match new_status:
		Status.WORKING:
			visible = false
			
		Status.NO_INPUT:
			visible = true
			if icon_no_input:
				texture = icon_no_input
				
		Status.OUTPUT_FULL:
			visible = true
			if icon_output_full:
				texture = icon_output_full
				
		Status.NO_RECIPE:
			visible = true
			if icon_no_recipe:
				texture = icon_no_recipe
