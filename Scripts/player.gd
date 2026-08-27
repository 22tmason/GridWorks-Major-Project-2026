extends Node2D

@export var speed: float = 600.0                   # Base camera glide speed at 1.0 zoom
@export var shift_speed_multiplier: float = 2.0    # Boost when holding Shift
@export var zoom_speed: float = 0.05               # Speed for classic mouse wheel scrolling
@export var trackpad_zoom_sensitivity: float = 0.02 # Lower = slower/smoother zoom
@export var min_zoom: float = 0.2                  # How far out you can zoom
@export var max_zoom: float = 3.0                  # How close in you can zoom

@onready var camera: Camera2D = $Camera2D

# --- Tag the player so the compass can securely find it ---
func _ready() -> void:
	add_to_group("player")


func _process(delta: float) -> void:
	# 1. Calculate WASD movement vector
	var direction = Vector2.ZERO
	if Input.is_key_pressed(KEY_D): direction.x += 1
	if Input.is_key_pressed(KEY_A): direction.x -= 1
	if Input.is_key_pressed(KEY_S): direction.y += 1
	if Input.is_key_pressed(KEY_W): direction.y -= 1
	
	# 2. Scale speed dynamically based on zoom (Divide by zoom so lower zoom = faster speed)
	var current_speed = speed / camera.zoom.x
	
	# 3. Apply Shift turbo boost if held down
	if Input.is_key_pressed(KEY_SHIFT):
		current_speed *= shift_speed_multiplier
	
	# 4. Apply normalized movement smoothly
	global_position += direction.normalized() * current_speed * delta

func _unhandled_input(event: InputEvent) -> void:
	var current_zoom = camera.zoom.x
	
	# Handle MacBook Trackpad Two-Finger Scroll Zooming
	if event is InputEventPanGesture:
		current_zoom -= event.delta.y * trackpad_zoom_sensitivity
		current_zoom = clamp(current_zoom, min_zoom, max_zoom)
		camera.zoom = Vector2(current_zoom, current_zoom)
		
	# Fallback for Standard Mouse Wheel Zooming
	elif event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			current_zoom += zoom_speed
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			current_zoom -= zoom_speed
			
		current_zoom = clamp(current_zoom, min_zoom, max_zoom)
		camera.zoom = Vector2(current_zoom, current_zoom)
