extends InventoryUI
class_name WorkshopInventoryUI

@onready var equip_barrel_container: HBoxContainer = $MainRegion/BarrelModifyUI/LeftRegion/GunSideview/EquippedBarrelContainer
@onready var inventory_gun_frame_container: GridContainer = $MainRegion/BarrelModifyUI/RightRegion/ScrollContainer/VBoxContainer/GunFrameContainer/GridContainer
@onready var inventory_normal_barrel_container: GridContainer = $MainRegion/BarrelModifyUI/RightRegion/ScrollContainer/VBoxContainer/NormalContainer/GridContainer
@onready var current_gun_frame_label: Label = $MainRegion/BarrelModifyUI/LeftRegion/GunSideview/CurrentGunFrame


func full_refresh_ui(forced: bool = false):
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
		item_inst.init(barrel_data, self, true, true)
		item_inst.select_item.connect(_on_item_ui_select)
		item_inst.interact_item.connect(_on_item_ui_interact)
	
	# INVENTORY STUFF
	for child in inventory_gun_frame_container.get_children():
		child.queue_free()
	for child in inventory_normal_barrel_container.get_children():
		child.queue_free()
	for barrel_data in GameManager.inventory_barrels:
		if not barrel_data.is_archetype_barrel:
			var item_inst: ItemUI = barrel_item_ui_prefab.instantiate()
			inventory_normal_barrel_container.add_child(item_inst)
			item_inst.init(barrel_data, self, false, true)
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
		var container = slot.get_node("HBoxContainer")
		var barrel = container.get_child(0)
		if barrel:
			leftmost_barrel = barrel
		continue
	
	if not leftmost_barrel:
		first_item = barrel_slots[-1].button
	else:
		first_item = leftmost_barrel.button
	
	return first_item


#### 
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
	get_first_item_for_focus().grab_focus.call_deferred() 


func _on_gun_frame_item_ui_select(gun_frame_item_ui: GunFrameItemUI, _data: GunFrameResource) -> void:
	if (current_selected_item_ui != null):
		current_selected_item_ui.unselected()
	
	current_selected_item_ui = gun_frame_item_ui
	# TODO: Add UI element to show gun frame stat
	SoundManager.play_ui_sound(sfx_click, "UI")


func _on_gun_frame_item_ui_interact(gun_frame_item_ui: GunFrameItemUI, data: GunFrameResource) -> void:
	var warning_text = GameManager.equip_gun_frame(data.frame_id)
	show_warning(warning_text)
	SoundManager.play_ui_sound(sfx_barrel_equip, "UI")
	current_gun_frame_icon.texture = data.shop_ui_sprite
	
	full_refresh_ui()
	get_first_item_for_focus().grab_focus.call_deferred()
