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
	super(event)
	if visible:
		var focused_ui: Control = current_focus_area.get_child(active_focus_idx) if current_focus_area else null
		if event.is_action_pressed("ui_cancel"):
			contextual_cancel(focused_ui.item_ui)


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
			shop_item_inst.init(self, barrel_data)
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
		shop_item_inst.init(self, gun_frame_data)
		shop_item_inst.item_ui.select_item.connect(_on_gun_frame_item_ui_select)
		shop_item_inst.item_ui.interact_item.connect(_on_gun_frame_item_ui_interact)
		shop_item_inst.item_ui.button.focus_entered.connect(_on_item_ui_button_focus_gained.bind(shop_item_inst.item_ui))
		shop_item_inst.item_ui.button.focus_exited.connect(_on_item_ui_button_focus_lost.bind(shop_item_inst.button))
		shop_item_inst.item_ui.button.pressed.connect(
			_on_item_ui_button_pressed.bind(shop_item_inst.item_ui)
		)
	
	set_focus_neighbour_wrapping(shop_barrel_container)
	set_focus_neighbour_wrapping(shop_gun_frame_container)
	set_region_focus_neighbor(shop_barrel_container, shop_gun_frame_container, Side.SIDE_TOP)
	
	await get_tree().process_frame
	var focus_area: Control = focus_area_callable.call()
	focus_area.grab_focus.call_deferred()


func contextual_cancel(focused_ui: Control) -> void:
	# Back out of inventory or detail focus instead of closing
	var cancel_focus: Callable = get_first_item_for_focus.bind(active_focus_idx)
	# Inventory item cancel
	if focused_ui is ItemUI:
		# Clicked Inventory UI -> Same Inventory UI
		if focused_ui.clicked_once:
			cancel_focus = get_inventory_focus.bind(active_focus_idx)
			clear_item_ui_highlight(focused_ui)
			_reset_sibling_saturation(focused_ui)
		# Hovered Inventory UI -> Active Inventory Slot
		else:
			close()
	elif focused_ui is GunFrameItemUI:
		# Clicked Inventory UI -> Same Inventory UI
		if focused_ui.clicked_once:
			cancel_focus = get_gun_frame_inventory_focus.bind(active_focus_idx)
			clear_item_ui_highlight(focused_ui)
			_reset_sibling_saturation(focused_ui)
		# Hovered Inventory UI -> Active Inventory Slot
		else:
			close()
	
	# TODO - handle gun frame ui
	
	get_viewport().set_input_as_handled()
	full_refresh_ui(cancel_focus)


func set_shopkeeper_chat(content: String) -> void:
	shopkeeper_chat.text = content
	shopkeeper_chat.visible_ratio = 0


func get_first_item_for_focus(idx: int = 0) -> Control:
	return get_inventory_focus(idx)


func get_gun_frame_inventory_focus(focus_idx: int = 0) -> Control:
	current_focus_area = shop_gun_frame_container
	
	var gun_frame_items = shop_gun_frame_container.get_children()
	for item in barrel_info_region.circle_ring.get_children():
		item.focus_mode = FocusMode.FOCUS_NONE
	for slot in shop_barrel_container.get_children():
		slot.item_ui.button.focus_mode = FocusMode.FOCUS_NONE
	for slot in gun_frame_items:
		slot.item_ui.button.focus_mode = FocusMode.FOCUS_ALL
	# TODO - defocus detail ui
	
	if gun_frame_items.size() > 0:
		return gun_frame_items[focus_idx].button
	# Fallback to inventory barrels if no frames available
	else:
		return get_inventory_focus()


func get_inventory_focus(focus_idx: int = 0) -> Control:
	current_focus_area = shop_barrel_container
	# Update focus area modes
	var inventory_barrel_items = shop_barrel_container.get_children()
	for slot in shop_gun_frame_container.get_children():
		slot.item_ui.button.focus_mode = FocusMode.FOCUS_NONE
	for slot in inventory_barrel_items:
		slot.item_ui.button.focus_mode = FocusMode.FOCUS_ALL
	for item in barrel_info_region.circle_ring.get_children():
		item.focus_mode = FocusMode.FOCUS_NONE
	
	# Fallback when no barrels in inventory
	if inventory_barrel_items:
		return inventory_barrel_items[focus_idx].button
	#TODO
	else:
		return


func get_barrel_detail_focus(idx: int = -1) -> Control:	
	# Update focus area modes
	var effect_detail_items = barrel_info_region.barrel_info_icon_effect_pool
	for slot in shop_barrel_container.get_children():
		slot.item_ui.button.focus_mode = FocusMode.FOCUS_NONE
	for slot in shop_gun_frame_container.get_children():
		slot.item_ui.button.focus_mode = FocusMode.FOCUS_NONE
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

func _get_active_focus_idx_on_button_focus(ui: ItemUI) -> int:
	# Shop ItemUI objects are wrapped in a ShopItemUI node
	return ui.get_parent().get_index()

func _get_current_focus_area_on_button_focus(ui: ItemUI) -> Control:
	# Shop ItemUI objects are wrapped in a ShopItemUI node
	return ui.get_parent().get_parent()


func _on_item_ui_interact(item_ui: ItemUI, data: BarrelDataResource) -> void:
	super(item_ui, data)
	
	if item_ui.is_locked:
		return
	
	var focus_area_callable: Callable = get_inventory_focus

	if not item_ui.is_purchased:
		item_ui.is_purchased = GameManager.purchase_barrel(data)
		if item_ui.is_purchased:
			SoundManager.play_ui_sound(sfx_purchase, "UI")
			item_ui.deselect()
			
			var available_slots: int = current_focus_area.get_child_count() - 1
			# If there are no more valid slots, focus on the other area
			if available_slots == 0:
				focus_area_callable = get_gun_frame_inventory_focus
				var next_available_slots: int = shop_gun_frame_container.get_child_count()
				if next_available_slots != 0:
					focus_area_callable = focus_area_callable.bind(0)
			# Move focus to the closest avaialble slot
			elif available_slots <= active_focus_idx:
				focus_area_callable = focus_area_callable.bind(-1)
			# Move focus the new UI in the same slot
			else:
				focus_area_callable = focus_area_callable.bind(active_focus_idx)
		else:
			SoundManager.play_ui_sound(sfx_too_expensive, "UI")
			focus_area_callable = focus_area_callable.bind(active_focus_idx)
	
	full_refresh_ui(focus_area_callable)


func _on_gun_frame_item_ui_select(gun_frame_item_ui: GunFrameItemUI, _data: GunFrameResource) -> void:
	if (current_selected_item_ui != null):
		current_selected_item_ui.deselect()
	
	current_selected_item_ui = gun_frame_item_ui
	# TODO: Add UI show gun frame stat
	# barrel_info_region.set_barrel_data_resource(data)
	SoundManager.play_ui_sound(sfx_click, "UI")


func _on_gun_frame_item_ui_interact(gun_frame_item_ui: GunFrameItemUI, data: GunFrameResource) -> void:
	var focus_area_callable: Callable = get_gun_frame_inventory_focus
	
	if not gun_frame_item_ui.is_purchased:
		gun_frame_item_ui.is_purchased = GameManager.purchase_gun_frame(data)
		if gun_frame_item_ui.is_purchased:
			SoundManager.play_ui_sound(sfx_purchase, "UI")
			gun_frame_item_ui.deselect()
			
			var available_slots: int = current_focus_area.get_child_count() - 1
			# If there are no more valid slots, focus on the other area
			if available_slots == 0:
				focus_area_callable = get_inventory_focus
				var next_available_slots: int = shop_barrel_container.get_child_count()
				if next_available_slots != 0:
					focus_area_callable = focus_area_callable.bind(0)
			# Move focus to the closest avaialble slot
			elif available_slots <= active_focus_idx:
				focus_area_callable = focus_area_callable.bind(-1)
			# Move focus the new UI in the same slot
			else:
				focus_area_callable = focus_area_callable.bind(active_focus_idx)
		else:
			SoundManager.play_ui_sound(sfx_too_expensive, "UI")
			focus_area_callable = focus_area_callable.bind(active_focus_idx)
		
		full_refresh_ui(focus_area_callable)
