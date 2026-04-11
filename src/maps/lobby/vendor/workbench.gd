extends Area3D
class_name Workbench

signal inventory_opened
signal inventory_closed

@onready var shop_ui: WorkshopInventoryUI = $UI/WorkshopInventoryUI
@export var interact_dist: float = 2.5


func _ready() -> void:
	shop_ui.inventory_opened.connect(inventory_opened.emit)
	shop_ui.inventory_closed.connect(inventory_closed.emit)
	shop_ui.visible = false


func interact() -> void:
	shop_ui.toggle()
	GameManager.player.input_dir = Vector2.ZERO
	GameManager.player.vel_horizontal = Vector2.ZERO
	GameManager.player.velocity = Vector3.ZERO


func get_interact_text() -> String:
	return "Modify Loadout"
