extends CanvasLayer

@onready var arrow: Polygon2D = $Arrow

var elevator: Node2D = null
var player: Node2D = null

func _process(_delta: float) -> void:
	# 1. Look for the TRUE Space Elevator safely using the GridManager!
	if not is_instance_valid(elevator):
		for cell in GridManager.grid_data:
			var building = GridManager.grid_data[cell]
			if is_instance_valid(building) and "phase_requirements" in building:
				elevator = building
				break
				
		if not is_instance_valid(elevator):
			arrow.visible = false
			return
			
	# 2. Look for the Player securely via Group
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if not is_instance_valid(player): 
			arrow.visible = false # --- FIX: Hide the arrow if player is missing! ---
			return

	# 3. Calculate how far the player is from home
	var dist = player.global_position.distance_to(elevator.global_position)
	
	if dist < 1200.0:
		arrow.visible = false
		return
		
	# 4. Compass Math (Only runs if far away)
	arrow.visible = true
	var screen_size = get_viewport().get_visible_rect().size
	var screen_center = screen_size / 2.0
	
	var direction = player.global_position.direction_to(elevator.global_position)
	var radius = min(screen_center.x, screen_center.y) - 80.0
	
	arrow.position = screen_center + (direction * radius)
	arrow.rotation = direction.angle()
