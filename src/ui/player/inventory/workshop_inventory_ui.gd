extends InventoryUI
class_name WorkshopInventoryUI

@onready var equip_barrel_container: HBoxContainer = $MainRegion/BarrelModifyUI/LeftRegion/GunSideview/EquippedBarrelContainer
@onready var inventory_gun_frame_container: GridContainer = $MainRegion/BarrelModifyUI/RightRegion/ScrollContainer/VBoxContainer/GunFrameContainer/GridContainer
@onready var inventory_normal_barrel_container: GridContainer = $MainRegion/BarrelModifyUI/RightRegion/ScrollContainer/VBoxContainer/NormalContainer/GridContainer
@onready var current_gun_frame_label: Label = $MainRegion/BarrelModifyUI/LeftRegion/GunSideview/CurrentGunFrame

var active_equip_idx: int = -1
var active_focus_idx: int = -1


# FIXME: Invert the equip slot UI order to match the gun barrels, do this at the end
# and avoid tangling any of the rest of this code up in it to prevent confusion.

func _ready() -> void:
	super()
	init_equip_barrels()


func _input(event: InputEvent) -> void:
	if visible:
		var focused_ui: Control = current_focus_area.get_child(active_focus_idx)
		var equipped_ui: BarrelEquipSlotUI = equip_barrel_container.get_child(active_equip_idx)
		if event.is_action_pressed("ui_cancel"):
			# Back out of inventory or detail focus instead of closing
			var cancel_focus: Callable = get_first_item_for_focus.bind(active_focus_idx)
			# Inventory item cancel
			if focused_ui is ItemUI:
				# Clicked Inventory UI -> Same Inventory UI
				if focused_ui.clicked_once:
					cancel_focus = get_inventory_focus.bind(active_focus_idx)
				# Hovered Inventory UI -> Active Equip Slot
				else:
					cancel_focus = get_equip_slot_focus.bind(active_equip_idx)
					active_focus_idx = active_equip_idx
					clear_item_ui_highlight(equipped_ui.item_ui)
			elif focused_ui is BarrelEquipSlotUI:
				# Clicked Equip Slot -> Same Equip Slot
				if equipped_ui.item_ui.clicked_once:
					cancel_focus = get_equip_slot_focus.bind(active_equip_idx)
					active_focus_idx = active_equip_idx
					clear_item_ui_highlight(equipped_ui.item_ui)
				# Hovered Equip Slot -> Close UI
				else:
					close()
			elif focused_ui is GunFrameItemUI:
				# Clicked Frame UI -> Same Frame UI
				if focused_ui.clicked_once:
					cancel_focus = get_gun_frame_focus.bind(active_focus_idx)
				# Hovered Frame UI -> Active Equip Slot
				else:
					cancel_focus = get_equip_slot_focus.bind(active_equip_idx)
					active_focus_idx = active_equip_idx
					clear_item_ui_highlight(equipped_ui.item_ui)
			
			get_viewport().set_input_as_handled()
			full_refresh_ui(cancel_focus)
		
		elif event.is_action_pressed("ui_tab_left"):
			get_viewport().set_input_as_handled()
			move_equip_slot(active_equip_idx, -1)
		
		elif event.is_action_pressed("ui_tab_right"):
			get_viewport().set_input_as_handled()
			move_equip_slot(active_equip_idx, 1)
		
		elif event.is_action_pressed("ui_change_gun_frame"):
			get_viewport().set_input_as_handled()
			var focus_area: Control = get_gun_frame_focus()
			focus_area.grab_focus.call_deferred()
		
		elif event.is_action_pressed("interact"):
			close()
			get_viewport().set_input_as_handled()


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
	var slots_count: int = equip_barrel_container.get_child_count()
	#var barrel_idx: int = 0
	#for i in range(barrel_slots.size() - 1, -1, -1):
	for i in range(slots_count):
		var barrel_slot: BarrelEquipSlotUI = barrel_slots[i]
		var barrel_item: ItemUI = barrel_slot.item_ui
		# Barrels we have data for
		var barrel_data: BarrelDataResource = equipped_barrels[i]
		if barrel_data == null:
			barrel_item.empty_slot()
		else:
			barrel_item.set_barrel_data(barrel_data, true, true)
		#barrel_idx += 1
	
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
			item_inst.button.pressed.connect(_on_item_ui_button_pressed.bind(item_inst))
	
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

### FOCUS METHODS

func get_first_item_for_focus(slot_idx: int = -1) -> Control:
	return get_equip_slot_focus(slot_idx)


func get_equip_slot_focus(slot_idx: int = -1) -> Control:
	current_focus_area = equip_barrel_container
	
	# Update focus area modes
	var barrel_slots = equip_barrel_container.get_children()
	var slot_count: int = equip_barrel_container.get_child_count() - 1
	for slot in barrel_slots:
		slot.focus_mode = FocusMode.FOCUS_ALL
	for item in inventory_normal_barrel_container.get_children():
		item.focus_mode = FocusMode.FOCUS_NONE
	
	if slot_idx == -1:
		# Focus on leftmost equipped barrel, 
		# or the rightmost empty slot if no barrels are equipped.
		var leftmost_barrel: ItemUI = null
		for i in range(slot_count):
			var slot: BarrelEquipSlotUI = barrel_slots[i]
			var barrel: ItemUI = slot.item_ui
			if not barrel.is_empty:
				leftmost_barrel = barrel
				break
			continue
		
		if not leftmost_barrel:
			return barrel_slots[-1].item_ui.button
		else:
			return leftmost_barrel.button
	else:
		return barrel_slots[slot_idx].item_ui.button


func get_inventory_focus(idx: int = -1) -> Control:
	current_focus_area = inventory_normal_barrel_container
	
	# Update focus area modes
	var inventory_barrel_items = inventory_normal_barrel_container.get_children()
	for slot in equip_barrel_container.get_children():
		slot.focus_mode = FocusMode.FOCUS_NONE
	for item in inventory_barrel_items:
		item.focus_mode = FocusMode.FOCUS_ALL
	
	# Fallback when no barrels in inventory
	if inventory_barrel_items:
		if idx != -1:
			return inventory_barrel_items[idx].button
		else:
			return inventory_barrel_items[0].button
	else:
		return get_equip_slot_focus(active_equip_idx)


func get_gun_frame_focus(idx: int = -1) -> Control:
	current_focus_area = inventory_gun_frame_container
	
	# Update focus area modes
	var inventory_gun_frame_items = inventory_gun_frame_container.get_children()
	for slot in equip_barrel_container.get_children():
		slot.focus_mode = FocusMode.FOCUS_NONE
	for item in inventory_gun_frame_items:
		item.focus_mode = FocusMode.FOCUS_ALL
	
	# Fallback when no barrels in inventory
	if inventory_gun_frame_items:
		if idx != -1:
			return inventory_gun_frame_items[idx].button
		else:
			return inventory_gun_frame_items[0].button
	else:
		return get_equip_slot_focus(active_equip_idx)


func get_barrel_detail_focus() -> Control:
	# TODO
	return null


#### Equip Barrel Helpers

func init_equip_barrels() -> void:
	var barrel_container_count: int = equip_barrel_container.get_child_count()
	for i in range(barrel_container_count):
		var slot: BarrelEquipSlotUI = equip_barrel_container.get_child(i)
		var item_ui: Control = slot.item_ui
		item_ui.select_item.connect(_on_item_ui_select)
		item_ui.interact_item.connect(_on_item_ui_interact)
		item_ui.button.pressed.connect(_on_item_ui_button_pressed.bind(item_ui))
		item_ui.button.focus_exited.connect(_on_item_ui_button_focus_lost.bind(item_ui.button))
		# Setup wrapping focus
		var prev_slot_idx: int = wrapi(i - 1, 0, barrel_container_count)
		var prev_slot: Control = equip_barrel_container.get_child(prev_slot_idx).item_ui
		var next_slot_idx: int = wrapi(i + 1, 0, barrel_container_count)
		var next_slot: Control = equip_barrel_container.get_child(next_slot_idx).item_ui
		item_ui.button.focus_neighbor_left = prev_slot.button.get_path()
		item_ui.button.focus_neighbor_right = next_slot.button.get_path()


func move_equip_slot(prev_idx: int, idx_diff: int) -> void:
	var equip_slots = equip_barrel_container.get_children()
	var slots_count = equip_barrel_container.get_child_count()
	
	var _slot = equip_barrel_container.get_child(active_equip_idx).item_ui
	if active_equip_idx == -1 or _slot.is_empty:
		get_viewport().set_input_as_handled()
		return
	
	var new_idx = wrapi(prev_idx + idx_diff, 0, slots_count)
	
	if (current_selected_item_ui != null):
		current_selected_item_ui.deselect()
	
	active_focus_idx = new_idx
	active_equip_idx = new_idx
	
	var _prev_idx_barrel = GameManager.equipped_barrels[prev_idx]
	var _new_idx_barrel = GameManager.equipped_barrels[new_idx]
	var selected_barrel_id: int = _prev_idx_barrel.barrel_id
	
	GameManager.remove_barrel(selected_barrel_id)
	
	if _new_idx_barrel:
		var affected_barrel_id: int = _new_idx_barrel.barrel_id
		GameManager.remove_barrel(affected_barrel_id)
		GameManager.equip_barrel(affected_barrel_id, prev_idx)
	
	GameManager.equip_barrel(selected_barrel_id, new_idx)
	
	full_refresh_ui(get_first_item_for_focus)
	get_viewport().set_input_as_handled()


#### Highlight/Focus helpers

func clear_item_ui_highlight(ui: Control) -> void:
	super(ui)
	toggle_ui_focus_neighbors(ui.button, true)


func persist_item_ui_highlight(ui: Control) -> void:
	ui.is_active_equip = true
	ui.border_selected.visible = true
	ui.button.add_theme_stylebox_override(
		"normal",
		ui.button.get_theme_stylebox("focus", "Button")
	)


func toggle_ui_focus_neighbors(ui: Control, is_enabled: bool = true) -> void:
	# TODO - is this neccesary? We should just shift focus area to detail when the barrel is clicked once
	# and return to the original focus area on cancel or accept
	for neighbor in [ui.focus_neighbor_left, ui.focus_neighbor_right, ui.focus_neighbor_top, ui.focus_neighbor_bottom]:
		if neighbor:
			var node = get_node(neighbor)
			node.focus_mode = FocusMode.FOCUS_ALL if is_enabled else FocusMode.FOCUS_NONE


#### Signal Callbacks

func _on_item_ui_select(ui: ItemUI, data: BarrelDataResource) -> void:
	SoundManager.play_ui_sound(sfx_click, "UI")
	
	if current_selected_item_ui != null:
		current_selected_item_ui.deselect()
	current_selected_item_ui = ui
	
	active_focus_idx = ui.get_index()
	
	if ui.is_locked:
		barrel_info_region.show_barrel_locked()
		return
	
	if data:
		barrel_info_region.set_barrel_data_resource(data)


func _on_item_ui_button_pressed(ui: Control) -> void:
	if ui.clicked_once:
		active_focus_idx = ui.get_index()
	if ui.is_equipped or ui.is_empty:
		active_equip_idx = ui.get_parent().get_index()


func _on_item_ui_button_focus_lost(button: Button) -> void:
	toggle_ui_focus_neighbors(button, true)


func _on_item_ui_interact(item_ui: ItemUI, data: BarrelDataResource) -> void:
	if item_ui.is_locked:
		show_warning("Not available in demo")
		return
	
	var focus_area_callable: Callable = get_equip_slot_focus.bind(active_equip_idx)
	
	# Equipped barrel slot UI
	if item_ui.is_equipped:
		var warning_text = GameManager.remove_barrel(data.barrel_id)
		SoundManager.play_ui_sound(sfx_barrel_equip, "UI")
		show_warning(warning_text)
		
		item_ui.empty_slot()
		
		# After removing barrel, keep equip idx the same so we can immediately
		# install an inventory barrel if we want.
		# Otherwise we can cancel to go back.
		var equip_ui: ItemUI = equip_barrel_container.get_child(active_equip_idx).item_ui
		clear_item_ui_highlight(equip_ui)
	
	# Empty equip slot UI
	elif item_ui.is_empty:
		# Change focus to Inventory barrels
		focus_area_callable = get_inventory_focus
		active_equip_idx = item_ui.get_parent().get_index()
		persist_item_ui_highlight(item_ui)
	
	# Inventory slot UI
	else:
		var warning_text = GameManager.equip_barrel(data.barrel_id, active_equip_idx)
		SoundManager.play_ui_sound(sfx_barrel_equip, "UI")
		show_warning(warning_text)
		
		# After installing a barrel, remove equip idx so we can move between equip slots
		var equip_ui: ItemUI = equip_barrel_container.get_child(active_equip_idx).item_ui
		clear_item_ui_highlight(equip_ui)
		active_equip_idx = -1
	
	full_refresh_ui(focus_area_callable)


func _on_gun_frame_item_ui_select(ui: GunFrameItemUI, _data: GunFrameResource) -> void:
	if (current_selected_item_ui != null):
		current_selected_item_ui.deselect()
	
	current_selected_item_ui = ui
	
	active_focus_idx = ui.get_index()
	# TODO: Add UI element to show gun frame stat
	SoundManager.play_ui_sound(sfx_click, "UI")


func _on_gun_frame_item_ui_interact(gun_frame_item_ui: GunFrameItemUI, data: GunFrameResource) -> void:
	var focus_area_callable: Callable = get_first_item_for_focus
	var warning_text = GameManager.equip_gun_frame(data.frame_id)
	show_warning(warning_text)
	SoundManager.play_ui_sound(sfx_barrel_equip, "UI")
	current_gun_frame_icon.texture = data.shop_ui_sprite
	
	full_refresh_ui(focus_area_callable)
