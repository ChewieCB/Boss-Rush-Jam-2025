extends Control
class_name GunCustomizationUI

signal ui_opened
signal ui_closed

@export var shop_title: String
@export var barrel_item_ui_prefab: PackedScene
@export var shop_item_ui_prefab: PackedScene
@export var current_inventory: Array[BarrelDataResource]
@export var sfx_open: AudioStream
@export var sfx_click: AudioStream
@export var sfx_purchase: AudioStream
@export var sfx_too_expensive: AudioStream
@export var sfx_barrel_equip: AudioStream

@onready var modify_bg: Control = $ModifyBG
@onready var modify_tab_btn: Button = $TitleRegion/HBoxContainer/ModifyTab/ModifyTabButton
@onready var shop_bg: Control = $ShopBG
@onready var shop_tab_btn: Button = $TitleRegion/HBoxContainer/ShopTab/ShopTabButton

var current_selected_item_ui = null

func _ready() -> void:
	# warning_label.visible = false
	# visible = false
	# barrel_desc.text = ""
	# GameManager.currency_changed.connect(full_refresh_ui.unbind(1))
	# GameManager.refresh_shop_ui.connect(full_refresh_ui)
	# shop_title_label.text = shop_title
	modify_bg.visible = true
	shop_bg.visible = false
	modify_tab_btn.grab_focus()
	modify_tab_btn.disabled = true

	modify_tab_btn.mouse_entered.connect(_on_modify_tab_button_focus_entered)
	modify_tab_btn.focus_entered.connect(_on_modify_tab_button_focus_entered)
	modify_tab_btn.mouse_exited.connect(_on_modify_tab_button_focus_exited)
	modify_tab_btn.focus_exited.connect(_on_modify_tab_button_focus_exited)

	shop_tab_btn.mouse_entered.connect(_on_shop_tab_button_focus_entered)
	shop_tab_btn.focus_entered.connect(_on_shop_tab_button_focus_entered)
	shop_tab_btn.mouse_exited.connect(_on_shop_tab_button_focus_exited)
	shop_tab_btn.focus_exited.connect(_on_shop_tab_button_focus_exited)

func full_refresh_ui():
	return
	# barrel_desc.text = ""

	# # EQUIPPED BARRELS
	# for child in archetype_barrel_container.get_children():
	# 	child.queue_free()
	# for child in equip_barrel_container.get_children():
	# 	child.queue_free()
	# for barrel_data in GameManager.equipped_barrels:
	# 	var item_inst = barrel_item_ui_prefab.instantiate()
	# 	if barrel_data.is_archetype_barrel:
	# 		archetype_barrel_container.add_child(item_inst)
	# 	else:
	# 		equip_barrel_container.add_child(item_inst)
	# 	item_inst.init(barrel_data, true, true)
	# 	item_inst.select_item.connect(_on_item_ui_select)
	# 	item_inst.interact_item.connect(_on_item_ui_interact)
	# 	item_inst.show_warning.connect(show_warning)
	# equip_title.text = "Equipped ({0}/{1})".format([len(GameManager.equipped_barrels), GameManager.player.current_gun.max_barrels])

	# # INVENTORY BARRELS
	# for child in inventory_barrel_container.get_children():
	# 	child.queue_free()
	# for barrel_data in GameManager.inventory_barrels:
	# 	var item_inst = barrel_item_ui_prefab.instantiate()
	# 	inventory_barrel_container.add_child(item_inst)
	# 	item_inst.init(barrel_data, false, true)
	# 	item_inst.select_item.connect(_on_item_ui_select)
	# 	item_inst.interact_item.connect(_on_item_ui_interact)
	# 	item_inst.show_warning.connect(show_warning)

	# # SHOP BARRELS
	# for child in shop_barrel_container.get_children():
	# 	child.queue_free()
	# if not has_custom_inventory:
	# 	current_inventory = GameManager.shop_barrels
	# for barrel_data in current_inventory:
	# 	if barrel_data in GameManager.inventory_barrels:
	# 		current_inventory.erase(barrel_data)

	# 	var shop_item_inst = shop_item_ui_prefab.instantiate()
	# 	shop_barrel_container.add_child(shop_item_inst)
	# 	shop_item_inst.init(barrel_data)
	# 	shop_item_inst.item_ui.select_item.connect(_on_item_ui_select)
	# 	shop_item_inst.item_ui.interact_item.connect(_on_item_ui_interact)
	# 	shop_item_inst.item_ui.show_warning.connect(show_warning)

func update_description(content: String) -> void:
	return

func show_warning(content: String, color: Color = Color.RED) -> void:
	if content.contains("Warning"):
		color = Color.YELLOW
	# warning_label.self_modulate = color
	# warning_label.text = content
	# warning_label.visible = true

func get_first_item_for_focus() -> void:
	return

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


func _on_modify_tab_button_pressed() -> void:
	modify_bg.visible = true
	modify_tab_btn.get_node("Border").visible = true
	modify_tab_btn.disabled = true
	shop_bg.visible = false
	shop_tab_btn.get_node("Border").visible = false
	shop_tab_btn.disabled = false
	SoundManager.play_ui_sound(sfx_click, "UI")

func _on_shop_tab_button_pressed() -> void:
	modify_bg.visible = false
	modify_tab_btn.get_node("Border").visible = false
	modify_tab_btn.disabled = false
	shop_bg.visible = true
	shop_tab_btn.get_node("Border").visible = true
	shop_tab_btn.disabled = true
	SoundManager.play_ui_sound(sfx_click, "UI")

func play_hover_sfx():
	SoundManager.play_button_hover_sfx()


func _on_modify_tab_button_focus_entered() -> void:
	play_hover_sfx()
	modify_tab_btn.text = "* Modify *"
	# modify_tab_btn.add_theme_color_override("font_color", Color(0.9, 0.77, 0))
	# shop_tab_btn.add_theme_color_override("font_color", Color(0, 0, 0))

func _on_shop_tab_button_focus_entered() -> void:
	play_hover_sfx()
	# modify_tab_btn.add_theme_color_override("font_color", Color(0, 0, 0))
	shop_tab_btn.text = "* Shop *"
	# shop_tab_btn.add_theme_color_override("font_color", Color(0.9, 0.77, 0))

func _on_modify_tab_button_focus_exited() -> void:
	modify_tab_btn.text = "Modify"

func _on_shop_tab_button_focus_exited() -> void:
	shop_tab_btn.text = "Shop"


func expand_button_size(tab_button: Control):
	const SCALE_FACTOR = 1.1
	pivot_offset = size / 2
	if tab_button.disabled:
		return
	var tween = tab_button.create_tween()
	tween.tween_property(tab_button, "scale", Vector2(SCALE_FACTOR, SCALE_FACTOR), 0.1)

func return_button_size(tab_button: Control):
	pivot_offset = size / 2
	var tween = tab_button.create_tween()
	tween.tween_property(tab_button, "scale", Vector2(1, 1), 0.1)
