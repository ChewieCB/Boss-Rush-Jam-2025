extends Control
class_name GunCustomizationUI

signal inventory_opened
signal inventory_closed
signal reset_barrel_info

@export var shop_title: String
@export var barrel_item_ui_prefab: PackedScene
@export var gun_frame_item_ui_prefab: PackedScene
@export var shop_barrel_item_ui_prefab: PackedScene
@export var shop_gun_frame_item_ui_prefab: PackedScene
@export var has_custom_inventory: bool = false
@export var current_inventory: Array[Resource]
@export var show_shop_first: bool = false
@export var sfx_open: AudioStream
@export var sfx_click: AudioStream
@export var sfx_purchase: AudioStream
@export var sfx_too_expensive: AudioStream
@export var sfx_barrel_equip: AudioStream
@export var current_gun_frame_icon: TextureRect

@onready var warning_label: Label = $MainRegion/BarrelModifyUI/LeftRegion/WarningLabel
@onready var modify_bg: Control = $ModifyBG
@onready var modify_tab_btn: Button = $TitleRegion/HBoxContainer/ModifyTab/ModifyTabButton
@onready var barrel_modify_ui: Control = $MainRegion/BarrelModifyUI
@onready var equip_barrel_container: HBoxContainer = $MainRegion/BarrelModifyUI/LeftRegion/GunSideview/EquippedBarrelContainer
@onready var inventory_gun_frame_container: GridContainer = $MainRegion/BarrelModifyUI/RightRegion/ScrollContainer/VBoxContainer/GunFrameContainer/GridContainer
@onready var inventory_normal_barrel_container: GridContainer = $MainRegion/BarrelModifyUI/RightRegion/ScrollContainer/VBoxContainer/NormalContainer/GridContainer
@onready var current_gun_frame_label: Label = $MainRegion/BarrelModifyUI/LeftRegion/GunSideview/CurrentGunFrame
@onready var inventory_scroll_container: ScrollContainer = $MainRegion/BarrelModifyUI/RightRegion/ScrollContainer

@onready var shop_bg: Control = $ShopBG
@onready var shop_tab_btn: Button = $TitleRegion/HBoxContainer/ShopTab/ShopTabButton
@onready var barrel_shop_ui: Control = $MainRegion/BarrelShopUI
@onready var shop_gun_frame_container: GridContainer = $MainRegion/BarrelShopUI/LeftRegion/ScrollContainer/VBoxContainer/GunFrameContainer/GridContainer
@onready var shop_normal_barrel_container: GridContainer = $MainRegion/BarrelShopUI/LeftRegion/ScrollContainer/VBoxContainer/NormalContainer/GridContainer
@onready var shopkeeper_chat: RichTextLabel = $MainRegion/BarrelShopUI/RightRegion/VendorAvatar/Chatbox/RichTextLabel
@onready var shop_scroll_container: ScrollContainer = $MainRegion/BarrelShopUI/LeftRegion/ScrollContainer

const SHOPKEEPER_CHAT_TEXT_SPEED = 1.0
const CONTROLLER_SCROLL_SPEED_COOEFFICIENT = 3.0

var current_selected_item_ui = null
var barrel_info_region: BarrelInfoRegion = null
var ui_transitioning = false

func _ready() -> void:
	warning_label.visible = false
	GameManager.currency_changed.connect(full_refresh_ui.unbind(1))
	GameManager.refresh_shop_ui.connect(full_refresh_ui)

	modify_bg.visible = not show_shop_first
	barrel_modify_ui.visible = not show_shop_first
	modify_tab_btn.disabled = not show_shop_first
	modify_tab_btn.get_node("Border").visible = not show_shop_first
	shop_bg.visible = show_shop_first
	barrel_shop_ui.visible = show_shop_first
	shop_tab_btn.disabled = show_shop_first
	shop_tab_btn.get_node("Border").visible = show_shop_first

	modify_tab_btn.mouse_entered.connect(_on_modify_tab_button_focus_entered)
	modify_tab_btn.focus_entered.connect(_on_modify_tab_button_focus_entered)
	modify_tab_btn.mouse_exited.connect(_on_modify_tab_button_focus_exited)
	modify_tab_btn.focus_exited.connect(_on_modify_tab_button_focus_exited)

	shop_tab_btn.mouse_entered.connect(_on_shop_tab_button_focus_entered)
	shop_tab_btn.focus_entered.connect(_on_shop_tab_button_focus_entered)
	shop_tab_btn.mouse_exited.connect(_on_shop_tab_button_focus_exited)
	shop_tab_btn.focus_exited.connect(_on_shop_tab_button_focus_exited)

	await get_tree().process_frame
	await get_tree().process_frame
	
	# HACK - 40 mins before submission deadline get it done
	var inventory_info = get_node("MainRegion/BarrelModifyUI/LeftRegion/BarrelInfoRegion")
	var shop_info = get_node("MainRegion/BarrelShopUI/RightRegion/BarrelInfoRegion")
	for info_region in [inventory_info, shop_info]:
		info_region.reset_ui()
	barrel_info_region = shop_info

	full_refresh_ui(true)
	
	modify_tab_btn.grab_focus()


func _process(delta: float) -> void:
	if not visible:
		return

	if shopkeeper_chat.visible_ratio < 1.0:
		shopkeeper_chat.visible_ratio += delta * SHOPKEEPER_CHAT_TEXT_SPEED

	# Scrolling the ScrollContainer for controller
	var controller_scroll_y = Input.get_axis("controller_scroll_up", "controller_scroll_down")
	if abs(controller_scroll_y) < GameManager.controller_deadzone:
		return
	else:
		var scroll_container = get_current_scroll_container()
		scroll_container.scroll_vertical += controller_scroll_y * CONTROLLER_SCROLL_SPEED_COOEFFICIENT
		scroll_container.scroll_vertical = clamp(scroll_container.scroll_vertical, 0, scroll_container.get_v_scroll_bar().max_value)

func _input(event: InputEvent) -> void:
	if visible:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
			close()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("switch_tab_left"):
			if shop_bg.visible:
				_on_modify_tab_button_pressed()
			return
		if event.is_action_pressed("switch_tab_right"):
			if modify_bg.visible:
				_on_shop_tab_button_pressed()
			return

func full_refresh_ui(forced = false):
	if not visible and not forced:
		return

	# EQUIPPED BARRELS
	for barrel_slot in equip_barrel_container.get_children():
		var container = barrel_slot.get_node("HBoxContainer")
		for child in container.get_children():
			child.queue_free()
	var index = 2
	for barrel_data in GameManager.equipped_barrels:
		var item_inst = barrel_item_ui_prefab.instantiate()
		equip_barrel_container.get_child(index).get_node("HBoxContainer").add_child(item_inst)
		index -= 1
		item_inst.init(barrel_data, true, true)
		item_inst.select_item.connect(_on_item_ui_select)
		item_inst.interact_item.connect(_on_item_ui_interact)
		item_inst.show_warning.connect(show_warning)

	# INVENTORY STUFF
	for child in inventory_gun_frame_container.get_children():
		child.queue_free()
	for child in inventory_normal_barrel_container.get_children():
		child.queue_free()
	for barrel_data in GameManager.inventory_barrels:
		if not barrel_data.is_archetype_barrel:
			var item_inst: ItemUI = barrel_item_ui_prefab.instantiate()
			inventory_normal_barrel_container.add_child(item_inst)
			item_inst.init(barrel_data, false, true)
			item_inst.select_item.connect(_on_item_ui_select)
			item_inst.interact_item.connect(_on_item_ui_interact)
			item_inst.show_warning.connect(show_warning)

	for gun_frame_data in GameManager.inventory_gun_frames:
		var item_inst: GunFrameItemUI = gun_frame_item_ui_prefab.instantiate()
		inventory_gun_frame_container.add_child(item_inst)
		item_inst.init(gun_frame_data, false, true)
		item_inst.select_gun_frame.connect(_on_gun_frame_item_ui_select)
		item_inst.interact_gun_frame.connect(_on_gun_frame_item_ui_interact)
	
	if GameManager.equipped_gun_frame:
		current_gun_frame_icon.texture = GameManager.equipped_gun_frame.shop_ui_sprite
	else:
		current_gun_frame_icon.texture = GameManager.starting_gun_frame.shop_ui_sprite


	# SHOP STUFF
	for child in shop_gun_frame_container.get_children():
		child.queue_free()
	for child in shop_normal_barrel_container.get_children():
		child.queue_free()
	if not has_custom_inventory:
		current_inventory = GameManager.shop_barrels
	for barrel_data in current_inventory:
		if barrel_data in GameManager.inventory_barrels:
			current_inventory.erase(barrel_data)
			continue
		if not barrel_data.is_archetype_barrel:
			var shop_item_inst = shop_barrel_item_ui_prefab.instantiate()
			shop_normal_barrel_container.add_child(shop_item_inst)
			shop_item_inst.init(barrel_data)
			shop_item_inst.item_ui.select_item.connect(_on_item_ui_select)
			shop_item_inst.item_ui.interact_item.connect(_on_item_ui_interact)
			shop_item_inst.item_ui.show_warning.connect(show_warning)

	for gun_frame_data in GameManager.shop_gun_frames:
		var shop_item_inst = shop_gun_frame_item_ui_prefab.instantiate()
		shop_gun_frame_container.add_child(shop_item_inst)
		shop_item_inst.init(gun_frame_data)
		shop_item_inst.gun_frame_item_ui.select_gun_frame.connect(_on_gun_frame_item_ui_select)
		shop_item_inst.gun_frame_item_ui.interact_gun_frame.connect(_on_gun_frame_item_ui_interact)

	if GameManager.equipped_gun_frame:
		current_gun_frame_label.text = "Current frame: {0}".format([GameManager.equipped_gun_frame.frame_name])

func toggle():
	warning_label.self_modulate = Color.WHITE
	warning_label.text = "Barrel effects applied in stock-to-muzzle direction"
	warning_label.visible = true
	SoundManager.play_sound(sfx_open, "SFX")
	if visible:
		close()
	else:
		open()

func open():
	GameManager.player.controls_disabled = true
	GameManager.gun_customize_ui = self
	GameManager.change_fmod_bgm_menu_is_up(true)
	full_refresh_ui(true)
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	GameManager.player.is_in_menu = true
	get_first_item_for_focus()
	inventory_opened.emit()


func close():
	GameManager.player.controls_disabled = false
	GameManager.gun_customize_ui = null
	GameManager.change_fmod_bgm_menu_is_up(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	GameManager.player.is_in_menu = false
	if visible:
		visible = false
	inventory_closed.emit()


func show_warning(content: String, color: Color = Color.RED) -> void:
	if content.contains("Warning"):
		color = Color.YELLOW
	warning_label.self_modulate = color
	warning_label.text = content
	warning_label.visible = true

func set_shopkeeper_chat(content: String) -> void:
	shopkeeper_chat.text = content
	shopkeeper_chat.visible_ratio = 0


func get_first_item_for_focus() -> void:
	if show_shop_first:
		shop_tab_btn.grab_focus()
	else:
		modify_tab_btn.grab_focus()

func _on_item_ui_select(item_ui: ItemUI, data: BarrelDataResource) -> void:
	SoundManager.play_ui_sound(sfx_click, "UI")
	if (current_selected_item_ui != null):
		current_selected_item_ui.unselected()
	current_selected_item_ui = item_ui
	if item_ui.is_locked:
		barrel_info_region.show_barrel_locked()
		return
	barrel_info_region.set_barrel_data_resource(data)


func _on_item_ui_interact(item_ui: ItemUI, data: BarrelDataResource) -> void:
	if item_ui.is_locked:
		show_warning("Not available in demo")
		return

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


func _on_gun_frame_item_ui_select(gun_frame_item_ui: GunFrameItemUI, _data: GunFrameResource) -> void:
	if (current_selected_item_ui != null):
		current_selected_item_ui.unselected()
	current_selected_item_ui = gun_frame_item_ui
	# TODO: Add UI show gun frame stat
	# barrel_info_region.set_barrel_data_resource(data)
	SoundManager.play_ui_sound(sfx_click, "UI")


func _on_gun_frame_item_ui_interact(gun_frame_item_ui: GunFrameItemUI, data: GunFrameResource) -> void:
	if not gun_frame_item_ui.is_purchased:
		gun_frame_item_ui.is_purchased = GameManager.purchase_gun_frame(data)
		if gun_frame_item_ui.is_purchased:
			SoundManager.play_ui_sound(sfx_purchase, "UI")
			gun_frame_item_ui.unselected()
		else:
			SoundManager.play_ui_sound(sfx_too_expensive, "UI")
	else:
		var warning_text = GameManager.equip_gun_frame(data.frame_id)
		show_warning(warning_text)
		SoundManager.play_ui_sound(sfx_barrel_equip, "UI")
		current_gun_frame_icon.texture = data.shop_ui_sprite
	full_refresh_ui()
	get_first_item_for_focus()

func _on_modify_tab_button_pressed() -> void:
	if ui_transitioning:
		return
	ui_transitioning = true
	SoundManager.play_ui_sound(sfx_click, "UI")
	barrel_info_region = get_node("MainRegion/BarrelModifyUI/LeftRegion/BarrelInfoRegion")
	barrel_info_region.reset_ui()
	modify_bg.visible = true
	modify_tab_btn.get_node("Border").visible = true
	modify_tab_btn.disabled = true
	shop_bg.visible = false
	shop_tab_btn.get_node("Border").visible = false
	shop_tab_btn.disabled = false
	barrel_modify_ui.modulate.a = 0
	barrel_modify_ui.visible = true
	var tween = self.create_tween()
	tween.tween_property(barrel_modify_ui, "modulate:a", 1, 0.25)
	var tween2 = self.create_tween()
	tween2.tween_property(barrel_shop_ui, "modulate:a", 0, 0.25)
	await tween2.finished
	barrel_shop_ui.visible = false
	modify_tab_btn.grab_focus()
	ui_transitioning = false

func _on_shop_tab_button_pressed() -> void:
	if ui_transitioning:
		return
	ui_transitioning = true
	SoundManager.play_ui_sound(sfx_click, "UI")
	shopkeeper_chat.visible_ratio = 0
	barrel_info_region = get_node("MainRegion/BarrelShopUI/RightRegion/BarrelInfoRegion")
	barrel_info_region.reset_ui()
	modify_bg.visible = false
	modify_tab_btn.get_node("Border").visible = false
	modify_tab_btn.disabled = false
	shop_bg.visible = true
	shop_tab_btn.get_node("Border").visible = true
	shop_tab_btn.disabled = true
	barrel_shop_ui.modulate.a = 0
	barrel_shop_ui.visible = true
	var tween = self.create_tween()
	tween.tween_property(barrel_modify_ui, "modulate:a", 0, 0.25)
	var tween2 = self.create_tween()
	tween2.tween_property(barrel_shop_ui, "modulate:a", 1, 0.25)
	await tween.finished
	barrel_modify_ui.visible = false
	shop_tab_btn.grab_focus()
	ui_transitioning = false


func get_current_scroll_container() -> ScrollContainer:
	if modify_bg.visible:
		return inventory_scroll_container
	else:
		return shop_scroll_container


func play_hover_sfx():
	SoundManager.play_button_hover_sfx()


func _on_modify_tab_button_focus_entered() -> void:
	play_hover_sfx()
	modify_tab_btn.text = "* Modify *"

func _on_shop_tab_button_focus_entered() -> void:
	play_hover_sfx()
	shop_tab_btn.text = "* Shop *"

func _on_modify_tab_button_focus_exited() -> void:
	modify_tab_btn.text = "Modify"

func _on_shop_tab_button_focus_exited() -> void:
	shop_tab_btn.text = "Shop"
