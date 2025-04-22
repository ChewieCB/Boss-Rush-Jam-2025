extends Control
class_name InventoryUI

@export var shop_title: String

@export var barrel_item_ui_prefab: PackedScene
@export var cost_label_ui_prefab: PackedScene
@export var shop_item_ui_prefab: PackedScene

@export var current_inventory: Array[BarrelDataResource]
@onready var has_custom_inventory: bool = current_inventory.size() > 0

@export var sfx_open: AudioStream
@export var sfx_click: AudioStream
@export var sfx_purchase: AudioStream
@export var sfx_too_expensive: AudioStream
@export var sfx_barrel_equip: AudioStream

@onready var shop_title_label: Label = $Title
@onready var equip_title: Label = $EquipBarrelSection/EquipTitle
@onready var equip_barrel_container: HBoxContainer = $EquipBarrelSection/EquippedBarrelBorder/EquippedBarrelContainer
@onready var barrel_desc: RichTextLabel = $EquipBarrelSection/BarrelDescription/RichTextLabel
@onready var inventory_barrel_container: GridContainer = $BarrelOptionsSection/VBoxContainer/InventoryBarrelSection/VBoxContainer/ScrollContainer/MarginContainer/GridContainer
@onready var shop_barrel_container: GridContainer = $BarrelOptionsSection/VBoxContainer/ShopBarrelSelection/VBoxContainer/ScrollContainer/MarginContainer/GridContainer
@onready var warning_label: Label = $EquipBarrelSection/WarningLabel
var current_selected_item_ui = null


func _ready() -> void:
	warning_label.visible = false
	visible = false
	barrel_desc.text = ""
	GameManager.currency_changed.connect(full_refresh_ui.unbind(1))
	GameManager.refresh_shop_ui.connect(full_refresh_ui)
	shop_title_label.text = shop_title


func _on_item_ui_select(item_ui: ItemUI, data: BarrelDataResource) -> void:
	if (current_selected_item_ui != null):
		current_selected_item_ui.unselected()
	current_selected_item_ui = item_ui
	update_description(data.barrel_desc)
	SoundManager.play_ui_sound(sfx_click, "UI")


func _on_item_ui_interact(item_ui: ItemUI, data: BarrelDataResource) -> void:
	if not item_ui.is_purchased:
		item_ui.is_purchased = GameManager.purchase_barrel(data)
		if item_ui.is_purchased:
			SoundManager.play_ui_sound(sfx_purchase, "UI")
			item_ui.unselected()
		else:
			SoundManager.play_ui_sound(sfx_too_expensive, "UI")
	elif item_ui.is_equipped:
		var warning_text = GameManager.remove_barrel(data.barrel_id)
		show_warning(warning_text)
		SoundManager.play_ui_sound(sfx_barrel_equip, "UI")
	else:
		var warning_text = GameManager.equip_barrel(data.barrel_id)
		show_warning(warning_text)
		SoundManager.play_ui_sound(sfx_barrel_equip, "UI")
	full_refresh_ui()
	get_first_item_for_focus()


func toggle():
	warning_label.self_modulate = Color.WHITE
	warning_label.text = "Barrel effects applied from left to right"
	warning_label.visible = true
	SoundManager.play_sound(sfx_open, "SFX")
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
	
	# EQUIPPED BARRELS
	for child in equip_barrel_container.get_children():
		child.queue_free()
	for barrel_data in GameManager.equipped_barrels:
		var item_inst = barrel_item_ui_prefab.instantiate()
		item_inst.init(barrel_data, true, true)
		equip_barrel_container.add_child(item_inst)
		item_inst.select_item.connect(_on_item_ui_select)
		item_inst.interact_item.connect(_on_item_ui_interact)
		item_inst.show_warning.connect(show_warning)
	equip_title.text = "Equipped ({0}/{1})".format([len(GameManager.equipped_barrels), GameManager.player.current_gun.max_barrels])
	
	# INVENTORY BARRELS
	for child in inventory_barrel_container.get_children():
		child.queue_free()
	for barrel_data in GameManager.inventory_barrels:
		var item_inst = barrel_item_ui_prefab.instantiate()
		item_inst.init(barrel_data, false, true)
		inventory_barrel_container.add_child(item_inst)
		item_inst.select_item.connect(_on_item_ui_select)
		item_inst.interact_item.connect(_on_item_ui_interact)
		item_inst.show_warning.connect(show_warning)
	
	# SHOP BARRELS
	for child in shop_barrel_container.get_children():
		child.queue_free()
	if not has_custom_inventory:
		current_inventory = GameManager.shop_barrels
	for barrel_data in current_inventory:
		if barrel_data in GameManager.inventory_barrels:
			current_inventory.erase(barrel_data)
		
		var item_container := VBoxContainer.new()
		shop_barrel_container.add_child(item_container)
		var item_inst = barrel_item_ui_prefab.instantiate()
		item_inst.init(barrel_data)
		item_container.add_child(item_inst)
		
		item_inst.select_item.connect(_on_item_ui_select)
		item_inst.interact_item.connect(_on_item_ui_interact)
		item_inst.show_warning.connect(show_warning)
		
		var cost_label_inst = cost_label_ui_prefab.instantiate()
		item_container.add_child(cost_label_inst)
		cost_label_inst.label.text = str(barrel_data.barrel_cost)
		
		if barrel_data.barrel_cost > GameManager.player_currency:
			item_inst.is_disabled = true
		for elem in [cost_label_inst.icon, cost_label_inst.label]:
			elem.modulate = Color.DIM_GRAY if item_inst.is_disabled else Color.WHITE


func update_description(_text: String):
	barrel_desc.text = _text


func open():
	full_refresh_ui()
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	#Engine.time_scale = 0.2
	GameManager.player.is_in_inventory = true
	get_first_item_for_focus()


func close():
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	#Engine.time_scale = 1
	GameManager.player.is_in_inventory = false


func show_warning(content: String):
	warning_label.self_modulate = Color.RED
	warning_label.text = content
	warning_label.visible = true


func get_first_item_for_focus():
	await get_tree().create_timer(0.01).timeout
	var item_to_focus = null
	if equip_barrel_container.get_child_count() > 0:
		item_to_focus = equip_barrel_container.get_child(0)
	elif inventory_barrel_container.get_child_count() > 0:
		item_to_focus = inventory_barrel_container.get_child(0)
	elif shop_barrel_container.get_child_count() > 0:
		item_to_focus = shop_barrel_container.get_child(0)

	if item_to_focus != null and item_to_focus.button != null:
		item_to_focus.button.grab_focus()
