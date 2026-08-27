extends Button

@onready var icon_rect: TextureRect = $MarginContainer/Icon
@onready var count_label: Label = $CountLabel

var associated_slot_index: int = -1
var current_item_id: String = ""
var is_crafting_button: bool = false

func _ready() -> void:
	# Connect the built-in mouse signals dynamically
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
var is_display_only: bool = false

func setup_display_slot(item_id: String) -> void:
	current_item_id = item_id
	is_display_only = true
	is_crafting_button = false
	associated_slot_index = -1
	
	if InventoryManager.item_database.has(item_id):
		var data = InventoryManager.item_database[item_id]
		icon_rect.texture = load(data["texture"])
		count_label.text = "" 
		tooltip_text = data["name"] + "\n" + data["description"]
		
func _on_mouse_entered() -> void:
	if current_item_id != "":
		InventoryManager.hovered_item_id = current_item_id

func _on_mouse_exited() -> void:
	# Only clear it if we are still the hovered item (prevents clearing when moving quickly between slots)
	if InventoryManager.hovered_item_id == current_item_id:
		InventoryManager.hovered_item_id = ""
		
func setup_inventory_slot(slot_idx: int, item_id: String, quantity: int) -> void:
	associated_slot_index = slot_idx
	current_item_id = item_id
	is_crafting_button = false
	
	if item_id == "" or quantity <= 0:
		icon_rect.texture = null
		count_label.text = ""
		tooltip_text = ""
	else:
		var data = InventoryManager.item_database[item_id]
		icon_rect.texture = load(data["texture"])
		count_label.text = str(quantity)
		tooltip_text = data["name"] + "\n" + data["description"]

func setup_crafting_slot(item_id: String) -> void:
	current_item_id = item_id
	is_crafting_button = true
	associated_slot_index = -1
	
	var data = InventoryManager.item_database[item_id]
	icon_rect.texture = load(data["texture"])
	count_label.text = ""
	
	var is_unlocked: bool = ProgressionManager.is_unlocked(item_id)
	disabled = not is_unlocked
	
	if is_unlocked:
		modulate = Color(1, 1, 1, 1)
		tooltip_text = data["name"] + "\n" + data["description"]
	else:
		modulate = Color(0.25, 0.25, 0.25, 0.6)
		tooltip_text = data["name"] + " [LOCKED]\nRequires Space Elevator Phase " + str(_get_required_phase(item_id))

func _get_required_phase(item_id: String) -> int:
	for phase in ProgressionManager.phase_unlocks:
		if item_id in ProgressionManager.phase_unlocks[phase]:
			return phase
	return 0

func _gui_input(event: InputEvent) -> void:
	if is_display_only or not ProgressionManager.is_unlocked(current_item_id):
		return
		
	if event is InputEventMouseButton and event.pressed:
		if current_item_id == "":
			return
			
		if is_crafting_button:
			var craft_amount = 0
			
			# --- NEW: Multiply the clicks by the global slider value! ---
			var base_batch = InventoryManager.craft_multiplier
			
			if event.button_index == MOUSE_BUTTON_LEFT:
				craft_amount = base_batch # Left click crafts exact slider amount
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				craft_amount = base_batch * 5 # Right click crafts 5x the slider amount for massive bulk
				
			if craft_amount > 0:
				InventoryManager.add_item(current_item_id, craft_amount)
				if get_node_or_null("/root/TutorialManager") != null:
					for i in range(craft_amount):
						TutorialManager.notify_item_crafted(current_item_id)
		else:
			if event.button_index == MOUSE_BUTTON_LEFT:
				var data = InventoryManager.item_database[current_item_id]
				if data.has("scene"):
					var building_scene = load(data["scene"])
					BuildManager.change_building(building_scene, current_item_id)
