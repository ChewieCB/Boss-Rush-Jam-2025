extends InventoryUI
class_name WorkshopInventoryUI

@onready var equip_barrel_container: HBoxContainer = $MainRegion/BarrelModifyUI/LeftRegion/GunSideview/EquippedBarrelContainer
@onready var inventory_gun_frame_container: GridContainer = $MainRegion/BarrelModifyUI/RightRegion/ScrollContainer/VBoxContainer/GunFrameContainer/GridContainer
@onready var inventory_normal_barrel_container: GridContainer = $MainRegion/BarrelModifyUI/RightRegion/ScrollContainer/VBoxContainer/NormalContainer/GridContainer
@onready var current_gun_frame_label: Label = $MainRegion/BarrelModifyUI/LeftRegion/GunSideview/CurrentGunFrame

var active_equip_idx: int = -1
var active_equip_ui: Control


func _ready() -> void:
	super()
	var barrel_container_count: int = equip_barrel_container.get_child_count()
	
	for i in range(barrel_container_count):
		var slot = equip_barrel_container.get_child(i)
		var item_ui: Control = slot.get_node("BarrelItemUI")
		item_ui.select_item.connect(_on_item_ui_select)
		item_ui.interact_item.connect(_on_item_ui_interact)
		item_ui.button.pressed.connect(_on_item_ui_button_pressed.bind(item_ui))
		item_ui.button.focus_exited.connect(_on_item_ui_button_focus_lost.bind(item_ui.button))
		
		var prev_slot_idx: int = wrapi(i - 1, 0, barrel_container_count)
		var prev_slot: Control = equip_barrel_container.get_child(prev_slot_idx).get_child(0)
		var next_slot_idx: int = wrapi(i + 1, 0, barrel_container_count)
		var next_slot: Control = equip_barrel_container.get_child(next_slot_idx).get_child(0)
		item_ui.button.focus_neighbor_left = prev_slot.button.get_path()
		item_ui.button.focus_neighbor_right = next_slot.button.get_path()


func _input(event: InputEvent) -> void:
	if visible:
		if event.is_action_pressed("ui_cancel"):
			# Back out of inventory or detail focus instead of closing
			if current_focus_area == inventory_normal_barrel_container or active_equip_idx != -1:
				var reverse_order: bool = current_focus_area == inventory_normal_barrel_container
				var cancel_focus: Callable = get_equip_slot_focus.bind(active_equip_idx, reverse_order)
				for i in range(equip_barrel_container.get_child_count()):
					var equip_ui = equip_barrel_container.get_child(i).get_child(0)
					clear_item_ui_highlight(equip_ui)
				active_equip_idx = -1
				full_refresh_ui(cancel_focus)
			# TODO - back out to inventory focus if we cancel a once-clicked inventory barrel
			#
			else:
				close()
				get_viewport().set_input_as_handled()
		elif event.is_action_pressed("interact"):
			close()
			get_viewport().set_input_as_handled()
		# FIXME - moving equipped barrels left/right
		elif event.is_action_pressed("ui_tab_left"):
			move_equip_slot(active_equip_idx, -1)
		elif event.is_action_pressed("ui_tab_right"):
			move_equip_slot(active_equip_idx, 1)
		#elif event is InputEventJoypadButton:
			#if event.is_pressed():
				#match event.button_index:
					#9:
						#move_equip_slot(active_equip_idx, -1)
					#10:
						#move_equip_slot(active_equip_idx, 1)
					#_:
						#return


func close() -> void:
	for i in range(equip_barrel_container.get_child_count()):
		var equip_ui = equip_barrel_container.get_child(i).get_child(0)
		clear_item_ui_highlight(equip_ui)
	super()


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


func get_first_item_for_focus(slot_idx: int = -1) -> Control:
	return get_equip_slot_focus(slot_idx, true)


func get_equip_slot_focus(slot_idx: int = -1, reverse_order: bool = false) -> Control:
	current_focus_area = equip_barrel_container
	# Update focus area modes
	var barrel_slots = equip_barrel_container.get_children()
	var slot_count: int = equip_barrel_container.get_child_count() - 1
	for slot in barrel_slots:
		slot.focus_mode = FocusMode.FOCUS_ALL
	for item in inventory_normal_barrel_container.get_children():
		item.focus_mode = FocusMode.FOCUS_NONE
	
	# FIXME - focus defaults to index 1 when empty
	if slot_idx == -1:
		# Focus on leftmost equipped barrel, or the rightmost empty slot if no
		# barrels are equipped.
		var leftmost_barrel: Control = null
		for i in range(slot_count):
			var slot = barrel_slots[i]
			var barrel = slot.get_child(0)
			if not barrel.is_empty:
				leftmost_barrel = barrel
				break
			continue
		
		# FIXME - what do we focus on when there are no barrels equipped?
		#  Will likely solve itself when we move to selecting empty barrel slots
		if not leftmost_barrel:
			return barrel_slots[-1].get_child(0).button
		else:
			return leftmost_barrel.button
	else:
		if reverse_order:
			slot_idx = remap(slot_idx, 0, slot_count, slot_count, 0)
		return barrel_slots[slot_idx].get_child(0).button


func get_inventory_focus() -> Control:
	current_focus_area = inventory_normal_barrel_container
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
		return get_equip_slot_focus(active_equip_idx, true)


func get_barrel_detail_focus() -> Control:
	# TODO
	return null

#### 


func move_equip_slot(current_idx: int, idx_diff: int) -> void:
	var equip_slots = equip_barrel_container.get_children()
	var slots_count = equip_barrel_container.get_child_count()
	
	#var equip_idx: int = remap(active_equip_idx, 0, slots_count - 1, slots_count - 1, 0)
	var _slot = equip_barrel_container.get_child(active_equip_idx).get_child(0)
	if active_equip_idx == -1 or _slot.is_empty:
		get_viewport().set_input_as_handled()
		return
	
	var new_idx = wrapi(current_idx + idx_diff, 0, slots_count)
	active_equip_idx = new_idx
	
	if (current_selected_item_ui != null):
		current_selected_item_ui.deselect()
	
	# Invert the ordering for the UI
	new_idx = remap(new_idx, 0, slots_count - 1, slots_count - 1, 0)
	current_idx = remap(current_idx, 0, slots_count - 1, slots_count - 1, 0)
	
	var _current_idx_barrel = GameManager.equipped_barrels[current_idx]
	var _new_idx_barrel = GameManager.equipped_barrels[new_idx]
	GameManager.equipped_barrels[current_idx] = _new_idx_barrel
	GameManager.equipped_barrels[new_idx] = _current_idx_barrel
	
	full_refresh_ui(get_first_item_for_focus)
	get_viewport().set_input_as_handled()


func clear_item_ui_highlight(ui: Control) -> void:
	super(ui)
	toggle_ui_focus_neighbors(ui.button, true)


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


func _on_item_ui_button_pressed(ui: Control) -> void:
	if ui.clicked_once:
		active_equip_idx = ui.get_parent().get_index()
		toggle_ui_focus_neighbors(ui.button, false)


func _on_item_ui_button_focus_lost(button: Button) -> void:
	toggle_ui_focus_neighbors(button, true)


func toggle_ui_focus_neighbors(ui: Control, is_enabled: bool = true) -> void:
	# TODO - is this neccesary? We should just shift focus area to detail when the barrel is clicked once
	# and return to the original focus area on cancel or accept
	for neighbor in [ui.focus_neighbor_left, ui.focus_neighbor_right, ui.focus_neighbor_top, ui.focus_neighbor_bottom]:
		var node = get_node(neighbor)
		if node:
			node.focus_mode = FocusMode.FOCUS_ALL if is_enabled else FocusMode.FOCUS_NONE


func _on_item_ui_interact(item_ui: ItemUI, data: BarrelDataResource) -> void:
	if item_ui.is_locked:
		show_warning("Not available in demo")
		return
	
	var item_slots = equip_barrel_container.get_children()
	var item_slot_idx: int = item_slots.size() - 1
	var equip_slot_idx = item_slots.find(item_ui.get_parent())
	
	if equip_slot_idx != -1:
		item_slot_idx -= equip_slot_idx
		#var max_slots: int = equip_barrel_container.get_child_count() - 1 
		#active_equip_idx = remap(item_slot_idx, 0, max_slots, max_slots, 0)
	
	var focus_area_callable: Callable = get_first_item_for_focus.bind(item_slot_idx)
	
	if not item_ui.is_purchased:
		if item_ui.is_empty:
			# Change focus to inventory barrels
			focus_area_callable = get_inventory_focus
			active_equip_idx = item_slot_idx
			persist_item_ui_highlight(item_ui)
			# TODO - make cancel change focus back to equip focus
		else:
			item_ui.is_purchased = GameManager.purchase_barrel(data)
			if item_ui.is_purchased:
				SoundManager.play_ui_sound(sfx_purchase, "UI")
				item_ui.deselect()
			else:
				SoundManager.play_ui_sound(sfx_too_expensive, "UI")
			active_equip_idx = -1
	elif item_ui.is_equipped:
		var warning_text = GameManager.remove_barrel(data.barrel_id)
		show_warning(warning_text)
		item_ui.empty_slot()
		SoundManager.play_ui_sound(sfx_barrel_equip, "UI")
		
		for i in range(equip_barrel_container.get_child_count()):
			var equip_ui = equip_barrel_container.get_child(i).get_child(0)
			clear_item_ui_highlight(equip_ui)
		focus_area_callable = get_equip_slot_focus.bind(active_equip_idx, false)
		
		active_equip_idx = -1
	else:
		var warning_text = GameManager.equip_barrel(data.barrel_id, active_equip_idx)
		show_warning(warning_text)
		SoundManager.play_ui_sound(sfx_barrel_equip, "UI")
		
		for i in range(equip_barrel_container.get_child_count()):
			var equip_ui = equip_barrel_container.get_child(i).get_child(0)
			clear_item_ui_highlight(equip_ui)
		focus_area_callable = get_equip_slot_focus.bind(active_equip_idx, true)
		
		active_equip_idx = -1
	
	full_refresh_ui(focus_area_callable)
	
	#if is_instance_valid(item_ui):
		#if item_ui.is_empty:
			## Change focus to inventory barrels
			#get_inventory_focus().grab_focus.call_deferred()
	#else:
		#get_equip_slot_focus().grab_focus.call_deferred()


func persist_item_ui_highlight(ui: Control) -> void:
	ui.is_active_equip = true
	ui.border_selected.visible = true
	ui.button.add_theme_stylebox_override(
		"normal",
		ui.button.get_theme_stylebox("focus", "Button")
	)


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
