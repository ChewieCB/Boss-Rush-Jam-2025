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
@onready var shop_barrel_container: GridContainer = $MainRegion/BarrelShopUI/LeftRegion/ScrollContainer/VBoxContainer/NormalContainer/GridContainer
@onready var shopkeeper_chat: RichTextLabel = $MainRegion/BarrelShopUI/RightRegion/VendorAvatar/Chatbox/RichTextLabel

const SHOPKEEPER_CHAT_TEXT_SPEED = 1.0


func _process(delta: float) -> void:
	super(delta)
	
	if shopkeeper_chat.visible_ratio < 1.0:
		shopkeeper_chat.visible_ratio += delta * SHOPKEEPER_CHAT_TEXT_SPEED


func full_refresh_ui(focus_area_callable: Callable, forced = false):
	if not visible and not forced:
		return
	
	for child in shop_gun_frame_container.get_children():
		child.queue_free()
	for child in shop_barrel_container.get_children():
		child.queue_free()
	
	if not has_custom_inventory:
		current_inventory = GameManager.shop_barrels
	# TODO - build focus neighbors for cycling inventory selection like modify inventory
	for barrel_data in current_inventory:
		if barrel_data in GameManager.inventory_barrels:
			current_inventory.erase(barrel_data)
			continue
		if not barrel_data.is_archetype_barrel:
			var shop_item_inst = shop_barrel_item_ui_prefab.instantiate()
			shop_barrel_container.add_child(shop_item_inst)
			shop_item_inst.init(barrel_data, self)
			shop_item_inst.item_ui.select_item.connect(_on_item_ui_select)
			shop_item_inst.item_ui.interact_item.connect(_on_item_ui_interact)
			shop_item_inst.item_ui.show_warning.connect(show_warning)
	
	var inv_container_count: int = shop_barrel_container.get_child_count()
	var cols: int = shop_barrel_container.columns
	for i in range(inv_container_count):
		var inv_ui = shop_barrel_container.get_child(i)
		var prev_inv_idx: int = wrapi(i - 1, 0, inv_container_count)
		var prev_inv: Control = shop_barrel_container.get_child(prev_inv_idx)
		var next_inv_idx: int = wrapi(i + 1, 0, inv_container_count)
		var next_inv: Control = shop_barrel_container.get_child(next_inv_idx)
		var up_inv_idx = wrapi(i - cols, 0, inv_container_count)
		var up_inv: Control = shop_barrel_container.get_child(up_inv_idx)
		var down_inv_idx = wrapi(i + cols, 0, inv_container_count)
		var down_inv: Control = shop_barrel_container.get_child(down_inv_idx)
		inv_ui.button.focus_neighbor_left = prev_inv.button.get_path()
		inv_ui.button.focus_neighbor_right = next_inv.button.get_path()
		inv_ui.button.focus_neighbor_top = up_inv.button.get_path()
		inv_ui.button.focus_neighbor_bottom = down_inv.button.get_path()
		
	 # TODO - add focus neighbours between topmost barrels in inventory and gun frames
	for gun_frame_data in GameManager.shop_gun_frames:
		var shop_item_inst = shop_gun_frame_item_ui_prefab.instantiate()
		shop_gun_frame_container.add_child(shop_item_inst)
		shop_item_inst.init(gun_frame_data, self)
		shop_item_inst.gun_frame_item_ui.select_gun_frame.connect(_on_gun_frame_item_ui_select)
		shop_item_inst.gun_frame_item_ui.interact_gun_frame.connect(_on_gun_frame_item_ui_interact)
		
		var focus_area: Control = focus_area_callable.call()
		# TODO - might not need this await
		#await get_tree().process_frame
		focus_area.grab_focus.call_deferred()


func set_shopkeeper_chat(content: String) -> void:
	shopkeeper_chat.text = content
	shopkeeper_chat.visible_ratio = 0


func get_first_item_for_focus() -> Control:
	return get_inventory_focus()


func get_gun_frame_inventory_focus() -> Control:
	var gun_frame_items = shop_gun_frame_container.get_children()
	for item in gun_frame_items:
		item.focus_mode = FocusMode.FOCUS_ALL
	# TODO - defocus detail ui
	
	if gun_frame_items:
		return gun_frame_items[0].button
	# Fallback to inventory barrels if no frames available
	else:
		return get_inventory_focus()


func get_inventory_focus() -> Control:
	# Update focus area modes
	var inventory_barrel_items = shop_barrel_container.get_children()
	# TODO - defocus detail ui
	#for slot in equip_barrel_container.get_children():
	#	slot.focus_mode = FocusMode.FOCUS_NONE
	for item in inventory_barrel_items:
		item.focus_mode = FocusMode.FOCUS_ALL
	
	# Fallback when no barrels in inventory
	if inventory_barrel_items:
		return inventory_barrel_items[0].button
	#TODO
	else:
		return


func get_barrel_detail_focus() -> Control:
	return


func _on_item_ui_select(item_ui: ItemUI, data: BarrelDataResource) -> void:
	SoundManager.play_ui_sound(sfx_click, "UI")
	
	if (current_selected_item_ui != null):
		current_selected_item_ui.deselect()
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
			item_ui.deselect()
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
	
	full_refresh_ui(get_first_item_for_focus)


func _on_gun_frame_item_ui_select(gun_frame_item_ui: GunFrameItemUI, _data: GunFrameResource) -> void:
	if (current_selected_item_ui != null):
		current_selected_item_ui.deselect()
	
	current_selected_item_ui = gun_frame_item_ui
	# TODO: Add UI show gun frame stat
	# barrel_info_region.set_barrel_data_resource(data)
	SoundManager.play_ui_sound(sfx_click, "UI")


func _on_gun_frame_item_ui_interact(gun_frame_item_ui: GunFrameItemUI, data: GunFrameResource) -> void:
	if not gun_frame_item_ui.is_purchased:
		gun_frame_item_ui.is_purchased = GameManager.purchase_gun_frame(data)
		if gun_frame_item_ui.is_purchased:
			SoundManager.play_ui_sound(sfx_purchase, "UI")
			gun_frame_item_ui.deselect()
		else:
			SoundManager.play_ui_sound(sfx_too_expensive, "UI")
	else:
		var warning_text = GameManager.equip_gun_frame(data.frame_id)
		show_warning(warning_text)
		SoundManager.play_ui_sound(sfx_barrel_equip, "UI")
		current_gun_frame_icon.texture = data.shop_ui_sprite
	
	full_refresh_ui(get_first_item_for_focus)
