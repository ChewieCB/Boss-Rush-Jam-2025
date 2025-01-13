extends Control
class_name InventoryUI

@export var barrel_item_ui_prefab: PackedScene

@onready var equip_title: Label = $EquipBarrelSection/EquipTitle
@onready var equip_barrel_container: HBoxContainer = $EquipBarrelSection/EquippedBarrelContainer
@onready var barrel_desc: RichTextLabel = $EquipBarrelSection/BarrelDescription/RichTextLabel
@onready var inventory_barrel_container: GridContainer = $InventoryBarrelSection/ScrollContainer/GridContainer

var current_selected_item_ui = null

func _ready() -> void:
	visible = false
	barrel_desc.text = ""

func toggle():
	if visible:
		close()
	else:
		open()
		
func full_refresh_ui():
	barrel_desc.text = ""
	for child in equip_barrel_container.get_children():
		child.queue_free()
	for barrel_data in GameManager.equipped_barrels:
		var item_inst = barrel_item_ui_prefab.instantiate()
		item_inst.init(barrel_data, true)
		equip_barrel_container.add_child(item_inst)
	equip_title.text = "Equipped ({0}/{1})".format([len(GameManager.equipped_barrels), GameManager.player.current_gun.max_barrels])

	for child in inventory_barrel_container.get_children():
		child.queue_free()
	for barrel_data in GameManager.inventory_barrels:
		var item_inst = barrel_item_ui_prefab.instantiate()
		item_inst.init(barrel_data, false)
		inventory_barrel_container.add_child(item_inst)

func update_description(_text: String):
	barrel_desc.text = _text

func open():
	full_refresh_ui()
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	Engine.time_scale = 0.2
	GameManager.player.is_in_inventory = true

func close():
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	Engine.time_scale = 1
	GameManager.player.is_in_inventory = false
