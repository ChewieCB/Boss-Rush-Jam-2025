extends Control
class_name GunCustomizationUI

signal inventory_opened
signal inventory_closed
signal reset_barrel_info

@export var shop_title: String
@export var barrel_item_ui_prefab: PackedScene
@export var shop_item_ui_prefab: PackedScene
@export var current_inventory: Array[Resource]
@export var sfx_open: AudioStream
@export var sfx_click: AudioStream
@export var sfx_purchase: AudioStream
@export var sfx_too_expensive: AudioStream
@export var sfx_barrel_equip: AudioStream

@onready var warning_label: Label = $MainRegion/BarrelModifyUI/LeftRegion/WarningLabel
@onready var has_custom_inventory: bool = current_inventory.size() > 0
@onready var modify_bg: Control = $ModifyBG
@onready var modify_tab_btn: Button = $TitleRegion/HBoxContainer/ModifyTab/ModifyTabButton
@onready var barrel_modify_ui: Control = $MainRegion/BarrelModifyUI
@onready var equip_barrel_container: HBoxContainer = $MainRegion/BarrelModifyUI/LeftRegion/GunSideview/EquippedBarrelContainer
@onready var inventory_archetype_barrel_container: GridContainer = $MainRegion/BarrelModifyUI/RightRegion/InventoryBarrelSection/VBoxContainer/ArchetypeContainer/GridContainer
@onready var inventory_normal_barrel_container: GridContainer = $MainRegion/BarrelModifyUI/RightRegion/InventoryBarrelSection/VBoxContainer/NormalContainer/GridContainer

@onready var shop_bg: Control = $ShopBG
@onready var shop_tab_btn: Button = $TitleRegion/HBoxContainer/ShopTab/ShopTabButton
@onready var barrel_shop_ui: Control = $MainRegion/BarrelShopUI
@onready var shop_archetype_barrel_container: GridContainer = $MainRegion/BarrelShopUI/LeftRegion/InventoryBarrelSection/VBoxContainer/ArchetypeContainer/GridContainer
@onready var shop_normal_barrel_container: GridContainer = $MainRegion/BarrelShopUI/LeftRegion/InventoryBarrelSection/VBoxContainer/NormalContainer/GridContainer
@onready var shopkeeper_chat: RichTextLabel = $MainRegion/BarrelShopUI/RightRegion/VendorAvatar/Chatbox/RichTextLabel

const SHOPKEEPER_CHAT_TEXT_SPEED = 1.0

var current_selected_item_ui = null
var barrel_info_region: BarrelInfoRegion = null


func _ready() -> void:
	warning_label.visible = false
	GameManager.currency_changed.connect(full_refresh_ui.unbind(1))
	GameManager.refresh_shop_ui.connect(full_refresh_ui)
	modify_bg.visible = true
	barrel_modify_ui.visible = true
	shop_bg.visible = false
	barrel_shop_ui.visible = false
	modify_tab_btn.disabled = true

	barrel_info_region = get_node("MainRegion/BarrelModifyUI/LeftRegion/BarrelInfoRegion")
	barrel_info_region.reset_ui()

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

	full_refresh_ui(true)
	modify_tab_btn.grab_focus()


func _process(delta: float) -> void:
	if shopkeeper_chat.visible_ratio < 1.0:
		shopkeeper_chat.visible_ratio += delta * SHOPKEEPER_CHAT_TEXT_SPEED

func _input(event: InputEvent) -> void:
	if visible:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
			close()
			get_viewport().set_input_as_handled()

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

	# INVENTORY BARRELS
	for child in inventory_archetype_barrel_container.get_children():
		child.queue_free()
	for child in inventory_normal_barrel_container.get_children():
		child.queue_free()
	for barrel_data in GameManager.inventory_barrels:
		var item_inst = barrel_item_ui_prefab.instantiate()
		if barrel_data.is_archetype_barrel:
			inventory_archetype_barrel_container.add_child(item_inst)
		else:
			inventory_normal_barrel_container.add_child(item_inst)
		item_inst.init(barrel_data, false, true)
		item_inst.select_item.connect(_on_item_ui_select)
		item_inst.interact_item.connect(_on_item_ui_interact)
		item_inst.show_warning.connect(show_warning)

	# SHOP BARRELS
	for child in shop_archetype_barrel_container.get_children():
		child.queue_free()
	for child in shop_normal_barrel_container.get_children():
		child.queue_free()
	if not has_custom_inventory:
		current_inventory = GameManager.shop_barrels
	for barrel_data in current_inventory:
		if barrel_data in GameManager.inventory_barrels:
			current_inventory.erase(barrel_data)
			continue
		var shop_item_inst = shop_item_ui_prefab.instantiate()
		if barrel_data.is_archetype_barrel:
			shop_archetype_barrel_container.add_child(shop_item_inst)
		else:
			shop_normal_barrel_container.add_child(shop_item_inst)
		shop_item_inst.init(barrel_data)
		shop_item_inst.item_ui.select_item.connect(_on_item_ui_select)
		shop_item_inst.item_ui.interact_item.connect(_on_item_ui_interact)
		shop_item_inst.item_ui.show_warning.connect(show_warning)

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
	full_refresh_ui(true)
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	GameManager.player.is_in_menu = true
	get_first_item_for_focus()
	inventory_opened.emit()


func close():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	GameManager.player.is_in_menu = false
	if visible and not GameManager.player.current_gun.is_reloading \
		and not GameManager.player.current_gun.is_spinning:
		visible = false
		GameManager.player.current_gun.spin_all_barrels()
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
	modify_tab_btn.grab_focus()
	# await get_tree().create_timer(0.02).timeout
	# if inventory_archetype_barrel_container.get_child_count() > 0:
	# 	inventory_archetype_barrel_container.get_child(0).grab_focus()
	# elif inventory_normal_barrel_container.get_child_count() > 0:
	# 	inventory_normal_barrel_container.get_child(0).grab_focus()
	# elif shop_normal_barrel_container.get_child_count() > 0:
	# 	shop_normal_barrel_container.get_child(0).grab_focus()
	# elif shop_normal_barrel_container.get_child_count() > 0:
	# 	shop_normal_barrel_container.get_child(0).grab_focus()

func _on_item_ui_select(item_ui: ItemUI, data: BarrelDataResource) -> void:
	if (current_selected_item_ui != null):
		current_selected_item_ui.unselected()
	current_selected_item_ui = item_ui
	barrel_info_region.set_barrel_data_resource(data)
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

func _on_shop_tab_button_pressed() -> void:
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
