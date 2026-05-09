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


func _input(event: InputEvent) -> void:
	if visible:
		var focused_ui: Control = current_focus_area.get_child(active_focus_idx) if current_focus_area else null
		if event.is_action_pressed("ui_cancel"):
			# TODO - back out of inventory or detail focus instead of closing
			#if current_focus_area == inventory_normal_barrel_container:
				#var cancel_focus: Control = get_equip_slot_focus()
				#var equip_ui = equip_barrel_container.get_child(active_ui_idx).get_child(0)
				#clear_item_ui_highlight(equip_ui)
				#active_ui_idx = -1
				#cancel_focus.grab_focus.call_deferred()
				#full_refresh_ui(get_equip_slot_focus)
			if active_focus_idx != -1:
				var cancel_focus_callable: Callable
				cancel_focus_callable = get_gun_frame_inventory_focus if \
				current_focus_area == shop_gun_frame_container else get_inventory_focus
				var active_ui = current_focus_area.get_child(active_focus_idx).item_ui
				active_ui.clicked_once = false
				for i in range(current_focus_area.get_child_count()):
					var ui = current_focus_area.get_child(i).item_ui
					clear_item_ui_highlight(ui)
				active_focus_idx = -1
				full_refresh_ui(cancel_focus_callable)
			else:
				close()
				get_viewport().set_input_as_handled()
		elif event.is_action_pressed("interact"):
			close()
			get_viewport().set_input_as_handled()
		
		if event.is_action("inv_show_barrel_detail"):
			if not event.is_pressed():
				return
			
			get_viewport().set_input_as_handled()
			if barrel_info_region.single_effect_detail.visible:
				hide_effect_detail_view(focused_ui)
			elif barrel_info_region.barrel_overview_detail.visible:
				show_effect_detail_view(focused_ui)


func full_refresh_ui(focus_area_callable: Callable, forced = false):
	if not visible and not forced:
		return
	
	for child in shop_gun_frame_container.get_children():
		shop_gun_frame_container.remove_child(child)
		child.queue_free()
	for child in shop_barrel_container.get_children():
		shop_barrel_container.remove_child(child)
		child.queue_free()
	
	if not has_custom_inventory:
		current_inventory = GameManager.shop_barrels
	
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
			shop_item_inst.button.focus_entered.connect(_on_item_ui_button_focus_gained.bind(shop_item_inst.item_ui))
			shop_item_inst.button.focus_exited.connect(_on_item_ui_button_focus_lost.bind(shop_item_inst.button))
			shop_item_inst.item_ui.button.pressed.connect(
				_on_item_ui_button_pressed.bind(shop_item_inst.item_ui)
			)
	 # TODO - add focus neighbours between topmost barrels in inventory and gun frames
	for gun_frame_data in GameManager.shop_gun_frames:
		var shop_item_inst = shop_gun_frame_item_ui_prefab.instantiate()
		shop_gun_frame_container.add_child(shop_item_inst)
		shop_item_inst.init(gun_frame_data, self)
		shop_item_inst.gun_frame_item_ui.select_gun_frame.connect(_on_gun_frame_item_ui_select)
		shop_item_inst.gun_frame_item_ui.interact_gun_frame.connect(_on_gun_frame_item_ui_interact)
		shop_item_inst.gun_frame_item_ui.button.focus_entered.connect(_on_item_ui_button_focus_gained.bind(shop_item_inst))
		shop_item_inst.gun_frame_item_ui.button.focus_exited.connect(_on_item_ui_button_focus_lost.bind(shop_item_inst.button))
		shop_item_inst.gun_frame_item_ui.button.pressed.connect(
			_on_item_ui_button_pressed.bind(shop_item_inst.gun_frame_item_ui)
		)
	
	set_focus_neighbour_wrapping(shop_barrel_container)
	set_focus_neighbour_wrapping(shop_gun_frame_container)
	set_region_focus_neighbor(shop_barrel_container, shop_gun_frame_container, Side.SIDE_TOP)
	
	await get_tree().process_frame
	var focus_area: Control = focus_area_callable.call()
	focus_area.grab_focus.call_deferred()


func set_shopkeeper_chat(content: String) -> void:
	shopkeeper_chat.text = content
	shopkeeper_chat.visible_ratio = 0


func get_first_item_for_focus() -> Control:
	return get_inventory_focus()


func get_gun_frame_inventory_focus() -> Control:
	current_focus_area = shop_gun_frame_container
	
	var gun_frame_items = shop_gun_frame_container.get_children()
	for item in barrel_info_region.circle_ring.get_children():
		item.focus_mode = FocusMode.FOCUS_NONE
	for slot in shop_barrel_container.get_children():
		slot.item_ui.button.focus_mode = FocusMode.FOCUS_NONE
	for slot in gun_frame_items:
		slot.gun_frame_item_ui.button.focus_mode = FocusMode.FOCUS_ALL
	# TODO - defocus detail ui
	
	if gun_frame_items:
		return gun_frame_items[0].button
	# Fallback to inventory barrels if no frames available
	else:
		return get_inventory_focus()


func get_inventory_focus(focus_idx: int = 0) -> Control:
	current_focus_area = shop_barrel_container
	# Update focus area modes
	var inventory_barrel_items = shop_barrel_container.get_children()
	for slot in shop_gun_frame_container.get_children():
		slot.gun_frame_item_ui.button.focus_mode = FocusMode.FOCUS_NONE
	for slot in inventory_barrel_items:
		slot.item_ui.button.focus_mode = FocusMode.FOCUS_ALL
	for item in barrel_info_region.circle_ring.get_children():
		item.focus_mode = FocusMode.FOCUS_NONE
	
	# Fallback when no barrels in inventory
	if inventory_barrel_items:
		return inventory_barrel_items[0].button
	#TODO
	else:
		return


func get_barrel_detail_focus(idx: int = -1) -> Control:	
	# Update focus area modes
	var effect_detail_items = barrel_info_region.circle_ring.get_children()
	for slot in shop_barrel_container.get_children():
		slot.item_ui.button.focus_mode = FocusMode.FOCUS_NONE
	for slot in shop_gun_frame_container.get_children():
		slot.gun_frame_item_ui.button.focus_mode = FocusMode.FOCUS_NONE
	for item in effect_detail_items:
		item.focus_mode = FocusMode.FOCUS_ALL
	
	if effect_detail_items:
		if idx != -1:
			return effect_detail_items[idx]
		else:
			return effect_detail_items[1]
	else:
		return get_inventory_focus(active_focus_idx)

###

func show_effect_detail_view(focused_ui: Control) -> void:
	var data: BarrelDataResource
	var _ui: ItemUI
	var _parent: Control = focused_ui.get_parent()
	var ui_idx: int = focused_ui.get_index()
	var parent_idx: int = _parent.get_index()
	
	if focused_ui is ItemUI or focused_ui is GunFrameItemUI:
		data = focused_ui.data
		_ui = focused_ui
		
		active_focus_idx = ui_idx
	
	if _ui.is_empty or _ui.is_locked:
		return
	
	barrel_info_region.show_effect_detail()
	
	current_selected_item_ui = focused_ui if focused_ui is ItemUI else focused_ui.item_ui
	
	if data:
		barrel_info_region.populate_detail_circle_ui(data)
		barrel_info_region.set_effect_detail_data(0)
		persist_item_ui_highlight(_ui)
		_desaturate_siblings(_ui)
		toggle_ui_focus_neighbors(_ui.button, false)
		var detail_focus: Control = get_barrel_detail_focus(active_effect_detail_idx)
		detail_focus.grab_focus.call_deferred()


func hide_effect_detail_view(focused_ui: Control) -> void:
	var _ui: ItemUI = focused_ui.item_ui if focused_ui is BarrelEquipSlotUI else focused_ui
	if _ui.is_empty:
		return
	
	barrel_info_region.show_barrel_overview()
	active_effect_detail_idx = -1
	clear_item_ui_highlight(_ui)
	_reset_sibling_saturation(focused_ui)
	# Clear the inventory highlighting if we have an inventory slot selected
	# but this method is called on an equip slot
	# TODO - add a conditional to trigger this
	for item in shop_barrel_container.get_children():
		if item == focused_ui:
			continue
		item.modulate = Color("#ffffff")
		clear_item_ui_highlight(item.item_ui)
	current_selected_item_ui = null
	toggle_ui_focus_neighbors(_ui.button, true)
	var focus_control: Control
	match current_focus_area:
		shop_barrel_container:
			focus_control = get_inventory_focus(active_focus_idx)
	focus_control.grab_focus.call_deferred()



###

func _on_item_ui_button_pressed(ui: Control) -> void:
	var parent: Control = ui.get_parent()
	if ui.clicked_once:
		active_focus_idx = parent.get_index()
	# Remove focus neighbors
	toggle_ui_focus_neighbors(ui, false)


func _on_item_ui_interact(item_ui: ItemUI, data: BarrelDataResource) -> void:
	super(item_ui, data)
	
	if item_ui.is_locked:
		return

	if not item_ui.is_purchased:
		item_ui.is_purchased = GameManager.purchase_barrel(data)
		if item_ui.is_purchased:
			SoundManager.play_ui_sound(sfx_purchase, "UI")
			item_ui.deselect()
		else:
			SoundManager.play_ui_sound(sfx_too_expensive, "UI")
	
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
		
		full_refresh_ui(get_first_item_for_focus)
