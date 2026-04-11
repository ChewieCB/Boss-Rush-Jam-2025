extends InventoryUI
class_name GunCustomizationUI

@export var shop_title: String
@export var shop_barrel_item_ui_prefab: PackedScene
@export var shop_gun_frame_item_ui_prefab: PackedScene
@export var has_custom_inventory: bool = false
@export var current_inventory: Array[Resource]
@export var show_shop_first: bool = false

@onready var shop_bg: Control = $ShopBG
@onready var barrel_shop_ui: Control = $MainRegion/BarrelShopUI
@onready var shop_gun_frame_container: GridContainer = $MainRegion/BarrelShopUI/LeftRegion/ScrollContainer/VBoxContainer/GunFrameContainer/GridContainer
@onready var shop_normal_barrel_container: GridContainer = $MainRegion/BarrelShopUI/LeftRegion/ScrollContainer/VBoxContainer/NormalContainer/GridContainer
@onready var shopkeeper_chat: RichTextLabel = $MainRegion/BarrelShopUI/RightRegion/VendorAvatar/Chatbox/RichTextLabel

const SHOPKEEPER_CHAT_TEXT_SPEED = 1.0


func _process(delta: float) -> void:
	super(delta)
	
	if shopkeeper_chat.visible_ratio < 1.0:
		shopkeeper_chat.visible_ratio += delta * SHOPKEEPER_CHAT_TEXT_SPEED


func full_refresh_ui(forced = false):
	if not visible and not forced:
		return
	
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
			shop_item_inst.init(barrel_data, self)
			shop_item_inst.item_ui.select_item.connect(_on_item_ui_select)
			shop_item_inst.item_ui.interact_item.connect(_on_item_ui_interact)
			shop_item_inst.item_ui.show_warning.connect(show_warning)

	for gun_frame_data in GameManager.shop_gun_frames:
		var shop_item_inst = shop_gun_frame_item_ui_prefab.instantiate()
		shop_gun_frame_container.add_child(shop_item_inst)
		shop_item_inst.init(gun_frame_data, self)
		shop_item_inst.gun_frame_item_ui.select_gun_frame.connect(_on_gun_frame_item_ui_select)
		shop_item_inst.gun_frame_item_ui.interact_gun_frame.connect(_on_gun_frame_item_ui_interact)


func set_shopkeeper_chat(content: String) -> void:
	shopkeeper_chat.text = content
	shopkeeper_chat.visible_ratio = 0


func get_first_item_for_focus() -> Control:
	var first_item: Control = shop_normal_barrel_container.get_child(0).button
	return first_item


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
	await get_tree().process_frame
	get_first_item_for_focus().grab_focus.call_deferred()


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
	await get_tree().process_frame
	get_first_item_for_focus().grab_focus.call_deferred()
