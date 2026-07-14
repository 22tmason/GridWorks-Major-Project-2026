extends Node2D

# --- BUILDING SYSTEM VARIABLES ---
enum Direction { UP, RIGHT, DOWN, LEFT }
@export var current_direction: Direction = Direction.DOWN
var is_placed := false
var is_item_ready: bool = false

# --- DRILL VARIABLES ---
@export var mining_speed: float = 2.0 # Seconds per item
@export var item_scene: PackedScene   # Drag your "TestItem" scene here in the inspector

@onready var mining_timer: Timer = $MiningTimer
@onready var output_marker: Marker2D = $OutputMarker # Where the item pops out
@onready var output_check_area: Area2D = $OutputMarker/OutputCheckArea # Moved up here!

var active_resource = null # Will store the ore node we are mining

func _ready() -> void:
	if not is_placed:
		BuildManager.current_preview = self
		modulate.a = 0.5
	else:
		_start_mining()

func _process(_delta: float) -> void:
	if is_placed:
		return
		
	var mouse_pos = get_global_mouse_position()
	var current_grid_cell = GridManager.world_to_grid(mouse_pos)
	var snapped_position = GridManager.grid_to_world(current_grid_cell)
	
	global_position = snapped_position

func _unhandled_input(event: InputEvent) -> void:
	if is_placed:
		return
		
	if event is InputEventKey and event.keycode == KEY_R and event.pressed:
		rotate_drill()
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var current_grid_cell = GridManager.world_to_grid(get_global_mouse_position())
		var success = GridManager.place_item(current_grid_cell, self)
		
		if success:
			is_placed = true
			modulate.a = 1.0
			_start_mining()
			
			# Spawn the next preview
			var next_drill = BuildManager.selected_scene.instantiate()
			if "current_direction" in next_drill:
				next_drill.current_direction = current_direction
			next_drill.rotation_degrees = rotation_degrees
			get_parent().add_child(next_drill)

func rotate_drill() -> void:
	current_direction = (current_direction + 1) % 4 as Direction
	rotation_degrees += 90

# --- MINING LOGIC ---
func _start_mining() -> void:
	mining_timer.wait_time = mining_speed
	# Ensure the timer is set to ONE SHOT in the inspector so it doesn't auto-loop
	mining_timer.timeout.connect(_on_mining_finished)
	mining_timer.start()

func _on_mining_finished() -> void:
	is_item_ready = true

func _physics_process(_delta: float) -> void:
	# Don't do anything if we are still holding it on the mouse
	if not is_placed: 
		return
		
	# Rapidly check every physics frame if we have an item waiting
	if is_item_ready:
		_try_spawn_item()
		
func _try_spawn_item() -> void:
	if not item_scene:
		push_error("Drill has no Item Scene assigned!")
		return
		
	var overlapping_things = output_check_area.get_overlapping_areas()
	
	for thing in overlapping_things:
		if thing.is_in_group("items"):
			# Still blocked! 
			# We return immediately, but _physics_process will try again next frame.
			return
			
	# If we make it down here, the space is clear!
	var new_item = item_scene.instantiate()
	new_item.global_position = output_marker.global_position
	get_tree().current_scene.add_child(new_item)
	
	# Reset the state so we stop checking
	is_item_ready = false
	
	# Start digging up the next item instantly!
	mining_timer.start()
