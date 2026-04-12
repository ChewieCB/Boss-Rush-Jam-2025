extends InventoryUI
class_name WorkshopInventoryUI

@onready var equip_barrel_container: HBoxContainer = $MainRegion/BarrelModifyUI/LeftRegion/GunSideview/EquippedBarrelContainer
@onready var inventory_gun_frame_container: GridContainer = $MainRegion/BarrelModifyUI/RightRegion/ScrollContainer/VBoxContainer/GunFrameContainer/GridContainer
@onready var inventory_normal_barrel_container: GridContainer = $MainRegion/BarrelModifyUI/RightRegion/ScrollContainer/VBoxContainer/NormalContainer/GridContainer
@onready var current_gun_frame_label: Label = $MainRegion/BarrelModifyUI/LeftRegion/GunSideview/CurrentGunFrame


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
		var test0 = item_ui.button
		var test1 = prev_slot.button
		var test2 = next_slot.button
		item_ui.button.focus_neighbor_left = prev_slot.button.get_path()
		item_ui.button.focus_neighbor_right = next_slot.button.get_path()
	
	get_viewport().gui_focus_changed.connect(_on_focus_changed)


func full_refresh_ui(forced: bool = false):
	if not visible and not forced:
		return
	
	# Instead of removing and re-instancing each equipped barrel, 
	# we clear and set the properties
	# EQUIPPED BARRELS
	var equipped_barrels := GameManager.equipped_barrels
	var equipped_barrels_count: int = equipped_barrels.size()
	var barrel_slots = equip_barrel_container.get_children()
	var barrel_idx: int = 0
	for i in range(barrel_slots.size() - 1, -1, -1):
		var barrel_slot = barrel_slots[i]
		var barrel_item: ItemUI = barrel_slot.get_node("BarrelItemUI")
		# Barrels we have data for
		if barrel_idx < equipped_barrels_count:
			var barrel_data: BarrelDataResource = equipped_barrels[barrel_idx]
			barrel_item.set_barrel_data(barrel_data, true, true)
			barrel_idx += 1
		# Empty barrel slots
		else:
			barrel_item.empty_slot()
	
	# INVENTORY STUFF
	for child in inventory_gun_frame_container.get_children():
		child.queue_free()
	for child in inventory_normal_barrel_container.get_children():
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
	
	if GameManager.equipped_gun_frame:
		current_gun_frame_icon.texture = GameManager.equipped_gun_frame.shop_ui_sprite
		current_gun_frame_label.text = "Current frame: {0}".format([GameManager.equipped_gun_frame.frame_name])
	else:
		current_gun_frame_icon.texture = GameManager.starting_gun_frame.shop_ui_sprite


func get_first_item_for_focus() -> Control:
	var first_item: Control
	# Focus on leftmost equipped barrel, or the rightmost empty slot if no
	# barrels are equipped.
	var barrel_slots = equip_barrel_container.get_children()
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
		first_item = barrel_slots[-1].get_child(0).button
	else:
		first_item = leftmost_barrel.button
	
	return first_item


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
		item_ui.empty_slot()
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
		current_selected_item_ui.deselect()
	
	current_selected_item_ui = gun_frame_item_ui
	# TODO: Add UI element to show gun frame stat
	SoundManager.play_ui_sound(sfx_click, "UI")


func _on_gun_frame_item_ui_interact(gun_frame_item_ui: GunFrameItemUI, data: GunFrameResource) -> void:
	var warning_text = GameManager.equip_gun_frame(data.frame_id)
	show_warning(warning_text)
	SoundManager.play_ui_sound(sfx_barrel_equip, "UI")
	current_gun_frame_icon.texture = data.shop_ui_sprite
	
	full_refresh_ui()
	await get_tree().process_frame
	get_first_item_for_focus().grab_focus.call_deferred()


func _on_focus_changed(node: Control) -> void:
	print("Gained focus: %s" % [node.name])
