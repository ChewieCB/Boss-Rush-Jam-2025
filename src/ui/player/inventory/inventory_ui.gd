extends Control
class_name InventoryUI

@export var barrel_item_ui_prefab: PackedScene
@export var shop_item_ui_prefab: PackedScene

@onready var equip_title: Label = $EquipBarrelSection/EquipTitle
@onready var equip_barrel_container: HBoxContainer = $EquipBarrelSection/EquippedBarrelContainer
@onready var barrel_desc: RichTextLabel = $EquipBarrelSection/BarrelDescription/RichTextLabel
@onready var inventory_barrel_container: GridContainer = $BarrelOptionsSection/VBoxContainer/InventoryBarrelSection/VBoxContainer/ScrollContainer/GridContainer
@onready var shop_barrel_container: GridContainer = $BarrelOptionsSection/VBoxContainer/ShopBarrelSelection/VBoxContainer/ScrollContainer/GridContainer
@onready var warning_label: Label = $EquipBarrelSection/WarningLabel

var current_selected_item_ui = null

func _ready() -> void:
	warning_label.visible = false
	visible = false
	barrel_desc.text = ""
	GameManager.currency_changed.connect(full_refresh_ui.unbind(1))


func toggle():
	warning_label.self_modulate = Color.WHITE
	warning_label.text = "Barrel effects applied from left to right"
	warning_label.visible = true
	if visible:
		close()
	else:
		open()


func _unhandled_input(event: InputEvent) -> void:
	if visible:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
			close()
			get_viewport().set_input_as_handled()


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
		
	for child in shop_barrel_container.get_children():
		child.queue_free()
	for barrel_data in GameManager.shop_barrels:
		var item_inst = shop_item_ui_prefab.instantiate()
		item_inst.init(barrel_data, false)
		shop_barrel_container.add_child(item_inst)
		if barrel_data.barrel_cost > GameManager.player_currency:
			item_inst.is_disabled = true

func update_description(_text: String):
	barrel_desc.text = _text

func open():
	full_refresh_ui()
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	#Engine.time_scale = 0.2
	GameManager.player.is_in_inventory = true

func close():
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	#Engine.time_scale = 1
	GameManager.player.is_in_inventory = false


func show_warning(content: String):
	warning_label.self_modulate = Color.RED
	warning_label.text = content
	warning_label.visible = true