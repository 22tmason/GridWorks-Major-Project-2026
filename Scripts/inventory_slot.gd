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
	count_label.text = "" # Free crafting uses no numeric counter text
	tooltip_text = data["name"] + "\n" + data["description"]

func _gui_input(event: InputEvent) -> void:
	# Check if the event is a mouse click and if the button was just pressed down
	if event is InputEventMouseButton and event.pressed:
		
		# Early exit if the slot is empty
		if current_item_id == "":
			return
			
		if is_crafting_button:
			var craft_amount = 0
			
			# Determine the amount based on which mouse button was clicked
			if event.button_index == MOUSE_BUTTON_LEFT:
				craft_amount = 1
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				craft_amount = 5
				
			# If a valid button was clicked, add the items!
			if craft_amount > 0:
				InventoryManager.add_item(current_item_id, craft_amount)
				
				# Safely notify the tutorial manager
				if get_node_or_null("/root/TutorialManager") != null:
					for i in range(craft_amount):
						TutorialManager.notify_item_crafted(current_item_id)
		else:
			# --- THE RESTORED LOGIC ---
			# If this is a normal inventory slot, left-clicking it equips the building
			if event.button_index == MOUSE_BUTTON_LEFT:
				var data = InventoryManager.item_database[current_item_id]
				if data.has("scene"):
					var building_scene = load(data["scene"])
					BuildManager.change_building(building_scene)
