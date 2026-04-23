extends InventoryUI
class_name WorkshopInventoryUI

@onready var equip_barrel_container: HBoxContainer = $MainRegion/BarrelModifyUI/LeftRegion/GunSideview/EquippedBarrelContainer
@onready var inventory_gun_frame_container: GridContainer = $MainRegion/BarrelModifyUI/RightRegion/ScrollContainer/VBoxContainer/GunFrameContainer/GridContainer
@onready var inventory_normal_barrel_container: GridContainer = $MainRegion/BarrelModifyUI/RightRegion/ScrollContainer/VBoxContainer/NormalContainer/GridContainer
@onready var current_gun_frame_label: Label = $MainRegion/BarrelModifyUI/LeftRegion/GunSideview/CurrentGunFrame

var active_equip_slot: int = -1


func _ready() -> void:
	super()
	var barrel_container_count: int = equip_barrel_container.get_child_count()
	
	for i in range(barrel_container_count):
		var slot = equip_barrel_container.get_child(i)
		var item_ui: Control = slot.get_node("BarrelItemUI")
		item_ui.select_item.connect(_on_item_ui_select)
		item_ui.interact_item.connect(_on_item_ui_interact)
		
		var prev_slot_idx: int = wrapi(i - 1, 0, barrel_container_count)
		var prev_slot: Control = equip_barrel_container.get_child(prev_slot_idx).get_child(0)
		var next_slot_idx: int = wrapi(i + 1, 0, barrel_container_count)
		var next_slot: Control = equip_barrel_container.get_child(next_slot_idx).get_child(0)
		item_ui.button.focus_neighbor_left = prev_slot.button.get_path()
		item_ui.button.focus_neighbor_right = next_slot.button.get_path()
	
	get_viewport().gui_focus_changed.connect(_on_focus_changed)


func _input(event: InputEvent) -> void:
	if visible:
		if event.is_action_pressed("ui_cancel"):
			# TODO - back out of inventory or detail focus instead of closing
			close()
			get_viewport().set_input_as_handled()
			return


func full_refresh_ui(focus_area_callable: Callable, forced: bool = false):
	if not visible and not forced:
		return
	
	# Instead of removing and re-instancing each equipped barrel, 
	# we clear and set the properties
	# EQUIPPED BARRELS
	var equipped_barrels := GameManager.equipped_barrels
	var barrel_slots = equip_barrel_container.get_children()
	var barrel_idx: int = 0
	for i in range(barrel_slots.size() - 1, -1, -1):
		var barrel_slot = barrel_slots[i]
		var barrel_item: ItemUI = barrel_slot.get_node("BarrelItemUI")
		# Barrels we have data for
		var barrel_data: BarrelDataResource = equipped_barrels[barrel_idx]
		if barrel_data == null:
			barrel_item.empty_slot()
		else:
			barrel_item.set_barrel_data(barrel_data, true, true)
		barrel_idx += 1
		# Empty barrel slots
	
	# INVENTORY STUFF
	for child in inventory_gun_frame_container.get_children():
		inventory_gun_frame_container.remove_child(child)
		child.queue_free()
	for child in inventory_normal_barrel_container.get_children():
		inventory_normal_barrel_container.remove_child(child)
		child.queue_free()
	
	for barrel_data in GameManager.inventory_barrels:
		if not barrel_data.is_archetype_barrel:
			var item_inst: ItemUI = barrel_item_ui_prefab.instantiate()
			inventory_normal_barrel_container.add_child(item_inst)
			item_inst.init(self)
			item_inst.set_barrel_data(barrel_data, false, true)
			item_inst.select_item.connect(_on_item_ui_select)
			item_inst.interact_item.connect(_on_item_ui_interact)
	
	for gun_frame_data in GameManager.inventory_gun_frames:
		var item_inst: GunFrameItemUI = gun_frame_item_ui_prefab.instantiate()
		inventory_gun_frame_container.add_child(item_inst)
		item_inst.init(gun_frame_data, self, false, true)
		item_inst.select_gun_frame.connect(_on_gun_frame_item_ui_select)
		item_inst.interact_gun_frame.connect(_on_gun_frame_item_ui_interact)
	
	set_focus_neighbour_wrapping(inventory_normal_barrel_container)
	set_focus_neighbour_wrapping(inventory_gun_frame_container)
	
	if GameManager.equipped_gun_frame:
		current_gun_frame_icon.texture = GameManager.equipped_gun_frame.shop_ui_sprite
		current_gun_frame_label.text = "Current frame: {0}".format([GameManager.equipped_gun_frame.frame_name])
	else:
		current_gun_frame_icon.texture = GameManager.starting_gun_frame.shop_ui_sprite
	
	await get_tree().process_frame
	var focus_area: Control = focus_area_callable.call()
	focus_area.grab_focus.call_deferred()


func get_first_item_for_focus() -> Control:
	return get_equip_slot_focus()


func get_equip_slot_focus() -> Control:
	# Update focus area modes
	var barrel_slots = equip_barrel_container.get_children()
	for slot in barrel_slots:
		slot.focus_mode = FocusMode.FOCUS_ALL
	for item in inventory_normal_barrel_container.get_children():
		item.focus_mode = FocusMode.FOCUS_NONE
	
	# FIXME - focus defaults to index 1 when empty
	# Focus on leftmost equipped barrel, or the rightmost empty slot if no
	# barrels are equipped.
	var leftmost_barrel: Control = null
	for i in range(barrel_slots.size() - 1, 0, -1):
		var slot = barrel_slots[i]
		var barrel = slot.get_child(0)
		if barrel:
			leftmost_barrel = barrel
		continue
	
	# FIXME - what do we focus on when there are no barrels equipped?
	#  Will likely solve itself when we move to selecting empty barrel slots
	if not leftmost_barrel:
		return barrel_slots[-1].get_child(0).button
	else:
		return leftmost_barrel.button


func get_inventory_focus() -> Control:
	# Update focus area modes
	var inventory_barrel_items = inventory_normal_barrel_container.get_children()
	for slot in equip_barrel_container.get_children():
		slot.focus_mode = FocusMode.FOCUS_NONE
	for item in inventory_barrel_items:
		item.focus_mode = FocusMode.FOCUS_ALL
	
	# Fallback when no barrels in inventory
	if inventory_barrel_items:
		return inventory_barrel_items[0].button
	else:
		return get_equip_slot_focus()


#### 
func _on_item_ui_select(item_ui: ItemUI, data: BarrelDataResource) -> void:
	SoundManager.play_ui_sound(sfx_click, "UI")
	
	if (current_selected_item_ui != null):
		current_selected_item_ui.deselect()
	current_selected_item_ui = item_ui
	
	if item_ui.is_locked:
		barrel_info_region.show_barrel_locked()
		return
	
	if data:
		barrel_info_region.set_barrel_data_resource(data)


func _on_item_ui_interact(item_ui: ItemUI, data: BarrelDataResource) -> void:
	if item_ui.is_locked:
		show_warning("Not available in demo")
		return
	
	var focus_area_callable: Callable = get_first_item_for_focus
	var item_slots = equip_barrel_container.get_children()
	var item_slot_idx: int = item_slots.size() - 1 - item_slots.find(item_ui.get_parent())
	
	if not item_ui.is_purchased:
		if item_ui.is_empty:
			# Change focus to inventory barrels
			focus_area_callable = get_inventory_focus
			active_equip_slot = item_slot_idx
			# TODO - make cancel change focus back to equip focus
		else:
			item_ui.is_purchased = GameManager.purchase_barrel(data)
			if item_ui.is_purchased:
				SoundManager.play_ui_sound(sfx_purchase, "UI")
				item_ui.deselect()
			else:
				SoundManager.play_ui_sound(sfx_too_expensive, "UI")
	elif item_ui.is_equipped:
		active_equip_slot = item_slot_idx
		var warning_text = GameManager.remove_barrel(data.barrel_id)
		show_warning(warning_text)
		item_ui.empty_slot()
		SoundManager.play_ui_sound(sfx_barrel_equip, "UI")
		focus_area_callable = get_equip_slot_focus
	else:
		var warning_text = GameManager.equip_barrel(data.barrel_id, active_equip_slot)
		show_warning(warning_text)
		SoundManager.play_ui_sound(sfx_barrel_equip, "UI")
		active_equip_slot = -1
	
	full_refresh_ui(focus_area_callable)
	
	#if is_instance_valid(item_ui):
		#if item_ui.is_empty:
			## Change focus to inventory barrels
			#get_inventory_focus().grab_focus.call_deferred()
	#else:
		#get_equip_slot_focus().grab_focus.call_deferred()


func _on_gun_frame_item_ui_select(gun_frame_item_ui: GunFrameItemUI, _data: GunFrameResource) -> void:
	if (current_selected_item_ui != null):
		current_selected_item_ui.deselect()
	
	current_selected_item_ui = gun_frame_item_ui
	# TODO: Add UI element to show gun frame stat
	SoundManager.play_ui_sound(sfx_click, "UI")


func _on_gun_frame_item_ui_interact(gun_frame_item_ui: GunFrameItemUI, data: GunFrameResource) -> void:
	var focus_area_callable: Callable = get_first_item_for_focus
	var warning_text = GameManager.equip_gun_frame(data.frame_id)
	show_warning(warning_text)
	SoundManager.play_ui_sound(sfx_barrel_equip, "UI")
	current_gun_frame_icon.texture = data.shop_ui_sprite
	
	full_refresh_ui(focus_area_callable)

func _on_focus_changed(node: Control) -> void:
	print("Gained focus: %s" % [node.name])
