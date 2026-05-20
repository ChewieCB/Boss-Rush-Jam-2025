extends Area3D
class_name Workbench

signal inventory_opened
signal inventory_closed

@onready var ui_layer: CanvasLayer = $UI
@onready var shop_ui: WorkshopInventoryUI = $UI/WorkshopInventoryUI
@export var interact_dist: float = 2.5


func _ready() -> void:
	shop_ui.inventory_opened.connect(inventory_opened.emit)
	shop_ui.inventory_closed.connect(inventory_closed.emit)
	ui_layer.visible = false
	ui_layer.process_mode = Node.PROCESS_MODE_DISABLED
	shop_ui.visible = false


func interact() -> void:
	if shop_ui.visible:
		ui_layer.visible = false
		ui_layer.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		ui_layer.visible = true
		ui_layer.process_mode = Node.PROCESS_MODE_INHERIT
	
	shop_ui.toggle()
	GameManager.player.input_dir = Vector2.ZERO
	GameManager.player.vel_horizontal = Vector2.ZERO
	GameManager.player.velocity = Vector3.ZERO


func get_interact_text() -> String:
	return "Modify Loadout"
