extends InventoryUI
class_name WorkshopInventoryUI

@export var equip_barrel_container: HBoxContainer
@export var inventory_gun_frame_container: EquippedFrameSideViewUI 
@export var inventory_normal_barrel_container: GridContainer

var active_equip_idx: int = -1

var available_gun_frames: Array


# FIXME: Invert the equip slot UI order to match the gun barrels, do this at the end
# and avoid tangling any of the rest of this code up in it to prevent confusion.

func _ready() -> void:
	super()
	init_equip_barrels()
	for ui: BarrelInfoIcon in barrel_info_region.barrel_info_icon_effect_pool:
		ui.focus_entered.connect(_on_effect_detail_focus_gained.bind(ui))
		#active_effect_detail_idx
	available_gun_frames = [GameManager.equipped_gun_frame] + \
		GameManager.inventory_gun_frames
	
	barrel_info_region.show_barrel_overview()
	var focused_ui: Control = get_first_item_for_focus().get_child(0)
	if focused_ui:
		hide_effect_detail_view(focused_ui)


func _input(event: InputEvent) -> void:
	if visible:
		# FIXME - cleaner fix for this race condition whne the current_focus_area is null
		var focused_ui: Control = current_focus_area.get_child(active_focus_idx) if current_focus_area else null
		var equipped_ui: BarrelEquipSlotUI = equip_barrel_container.get_child(active_equip_idx) \
		if active_equip_idx < equip_barrel_container.get_child_count() else null
		
		if event.is_action_pressed("ui_cancel"):
			contextual_cancel(focused_ui, equipped_ui)
		
		if current_selected_item_ui != null:
			for ui_action in ["ui_left", "ui_right", "ui_up", "ui_down"]:
				if event.is_action(ui_action):
					get_viewport().set_input_as_handled()
		
		if event.is_action("inv_ui_tab_left") or event.is_action("inv_ui_tab_right"):
			if not event.is_pressed():
				return
				
			var dir: int = round(Input.get_axis("inv_ui_tab_left", "inv_ui_tab_right"))
			if dir == 0:
				return
			
			get_viewport().set_input_as_handled()
			if equipped_ui.item_ui.clicked_once:
				move_equip_slot(active_equip_idx, dir)
			else:
				change_gun_frame(dir)
		
		if event.is_action("inv_show_barrel_detail"):
			if not event.is_pressed():
				return
			
			get_viewport().set_input_as_handled()
			if barrel_info_region.single_effect_detail.visible:
				hide_effect_detail_view(focused_ui)
			elif barrel_info_region.barrel_overview_detail.visible:
				show_effect_detail_view(focused_ui)
		
		# TODO - rework to cycle frames left/right
		elif event.is_action_pressed("inv_ui_change_gun_frame"):
			get_viewport().set_input_as_handled()
			pass
		
		elif event.is_action_pressed("interact"):
			close()
			get_viewport().set_input_as_handled()


func open() -> void:
	available_gun_frames = [GameManager.equipped_gun_frame] + \
		GameManager.inventory_gun_frames
	inventory_gun_frame_container.set_frame_icons(
		GameManager.equipped_gun_frame, 
		available_gun_frames,
	)
	super()


func close() -> void:
	for i in range(equip_barrel_container.get_child_count()):
		var equip_ui = equip_barrel_container.get_child(i).item_ui
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
			item_inst.button.focus_entered.connect(_on_item_ui_button_focus_gained.bind(item_inst))
			item_inst.button.focus_exited.connect(_on_item_ui_button_focus_lost.bind(item_inst.button))
	
	set_focus_neighbour_wrapping(inventory_normal_barrel_container)
	
	await get_tree().process_frame
	
	var focus_area: Control = focus_area_callable.call()
	_reset_sibling_saturation(focus_area)
	focus_area.grab_focus.call_deferred()


### CONTEXTUAL HELPERS

func contextual_cancel(focused_ui: Control, equipped_ui: Control) -> void:
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
			_reset_sibling_saturation(equipped_ui.item_ui)
			current_selected_item_ui = null
	
	elif focused_ui is BarrelEquipSlotUI:
		# Clicked Equip Slot -> Same Equip Slot
		if equipped_ui.item_ui.clicked_once:
			cancel_focus = get_equip_slot_focus.bind(active_equip_idx)
			active_focus_idx = active_equip_idx
			clear_item_ui_highlight(equipped_ui.item_ui)
			_reset_sibling_saturation(equipped_ui.item_ui)
			current_selected_item_ui = null
		# Hovered Equip Slot -> Close UI
		else:
			close()
	
	_reset_sibling_saturation(focused_ui)
	get_viewport().set_input_as_handled()
	full_refresh_ui(cancel_focus)


func show_effect_detail_view(focused_ui: Control) -> void:
	var data: BarrelDataResource
	var _ui: ItemUI
	var _parent: Control = focused_ui.get_parent()
	var ui_idx: int = focused_ui.get_index()
	var parent_idx: int = _parent.get_index()
	
	if focused_ui is ItemUI:
		data = focused_ui.data
		_ui = focused_ui
		
		active_focus_idx = ui_idx
		if _parent is BarrelEquipSlotUI:
			active_focus_idx = parent_idx
			active_equip_idx = parent_idx
	elif focused_ui is BarrelEquipSlotUI:
		data = focused_ui.item_ui.data
		_ui = focused_ui.item_ui
		
		active_equip_idx = ui_idx
	elif focused_ui is GunFrameItemUI:
		return
	
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
	for item in inventory_normal_barrel_container.get_children():
		if item == focused_ui:
			continue
		item.modulate = Color("#ffffff")
		clear_item_ui_highlight(item)
	current_selected_item_ui = null
	toggle_ui_focus_neighbors(_ui.button, true)
	var focus_control: Control
	match current_focus_area:
		equip_barrel_container:
			focus_control = get_equip_slot_focus(active_focus_idx)
		inventory_normal_barrel_container:
			focus_control = get_inventory_focus(active_focus_idx)
	focus_control.grab_focus.call_deferred()

### FOCUS METHODS

func get_first_item_for_focus(slot_idx: int = -1) -> Control:
	return get_equip_slot_focus(slot_idx)


func get_equip_slot_focus(slot_idx: int = -1) -> Control:
	current_focus_area = equip_barrel_container
	
	# Update focus area modes
	var barrel_slots = equip_barrel_container.get_children()
	var slot_count: int = equip_barrel_container.get_child_count() - 1
	for slot in barrel_slots:
		slot.item_ui.button.focus_mode = FocusMode.FOCUS_ALL
	for item in inventory_normal_barrel_container.get_children():
		item.button.focus_mode = FocusMode.FOCUS_NONE
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
		slot.item_ui.button.focus_mode = FocusMode.FOCUS_NONE
	for item in inventory_barrel_items:
		item.button.focus_mode = FocusMode.FOCUS_ALL
	
	# Fallback when no barrels in inventory
	if inventory_barrel_items:
		if idx != -1:
			return inventory_barrel_items[idx].button
		else:
			return inventory_barrel_items[0].button
	else:
		return get_equip_slot_focus(active_equip_idx)


func get_barrel_detail_focus(idx: int = -1) -> Control:
	#current_focus_area = barrel_info_region.circle_ring
	var effect_detail_items = barrel_info_region.circle_ring.get_children()
	
	# Update focus area modes
	for slot in equip_barrel_container.get_children():
		slot.item_ui.button.focus_mode = FocusMode.FOCUS_NONE
	for item in effect_detail_items:
		item.focus_mode = FocusMode.FOCUS_ALL
	
	if effect_detail_items:
		if idx != -1:
			return effect_detail_items[idx]
		else:
			return effect_detail_items[1]
	else:
		return get_equip_slot_focus(active_equip_idx)


#### Equip Barrel Helpers

func init_equip_barrels() -> void:
	var barrel_container_count: int = equip_barrel_container.get_child_count()
	for i in range(barrel_container_count):
		var slot: BarrelEquipSlotUI = equip_barrel_container.get_child(i)
		var item_ui: Control = slot.item_ui
		item_ui.select_item.connect(_on_item_ui_select)
		item_ui.interact_item.connect(_on_item_ui_interact)
		item_ui.button.pressed.connect(_on_item_ui_button_pressed.bind(item_ui))
		item_ui.button.focus_entered.connect(_on_item_ui_button_focus_gained.bind(item_ui))
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
	# Re-trigger the pressed state
	var new_active_slot: BarrelEquipSlotUI = equip_barrel_container.get_child(active_equip_idx)
	new_active_slot.item_ui._on_button_pressed()
	_reset_sibling_saturation(new_active_slot.item_ui)
	_desaturate_siblings(new_active_slot.item_ui)
	get_viewport().set_input_as_handled()


func change_gun_frame(idx_diff: int) -> void:
	var current_idx: int = available_gun_frames.find(GameManager.equipped_gun_frame)
	var new_idx: int = wrapi(current_idx + idx_diff, 0, available_gun_frames.size())
	var new_frame = available_gun_frames[new_idx]
	
	var _warning_text = GameManager.equip_gun_frame(new_frame.frame_id)
	SoundManager.play_ui_sound(sfx_barrel_equip, "UI")
	
	var focus_area = get_equip_slot_focus.bind(active_focus_idx)
	full_refresh_ui(focus_area)
	inventory_gun_frame_container.set_frame_icons(
		GameManager.equipped_gun_frame, 
		available_gun_frames,
		Vector2.LEFT if idx_diff < 0 else Vector2.RIGHT
	)


#### Highlight/Focus helpers

#func clear_item_ui_highlight(ui: ItemUI) -> void:
	#super(ui)
	#toggle_ui_focus_neighbors(ui.button, true)
#
#
#func persist_item_ui_highlight(ui: Control) -> void:
	#ui.is_active_equip = true
	#ui.border_selected.visible = true
	#ui.button.add_theme_stylebox_override(
		#"normal",
		#ui.button.get_theme_stylebox("focus", "Button")
	#)


#func toggle_ui_focus_neighbors(ui: Control, is_enabled: bool = true) -> void:
	#for neighbor in [ui.focus_neighbor_left, ui.focus_neighbor_right, ui.focus_neighbor_top, ui.focus_neighbor_bottom]:
		#if neighbor:
			#var node = get_node(neighbor)
			#if node:
				#node.focus_mode = FocusMode.FOCUS_ALL if is_enabled else FocusMode.FOCUS_NONE


#### Signal Callbacks


func _on_item_ui_button_pressed(ui: Control) -> void:
	var parent: Control = ui.get_parent()
	if ui.clicked_once:
		active_focus_idx = parent.get_index() if parent is BarrelEquipSlotUI else ui.get_index()
	if ui.is_equipped or ui.is_empty:
		active_equip_idx = parent.get_index()
	# Remove focus neighbors
	toggle_ui_focus_neighbors(ui, false)


func _get_active_focus_idx_on_button_focus(ui: ItemUI) -> int:
	var _parent: Control = ui.get_parent()
	return _parent.get_index() if _parent is BarrelEquipSlotUI else ui.get_index()

func _get_current_focus_area_on_button_focus(ui: ItemUI) -> Control:
	var _parent: Control = ui.get_parent()
	return equip_barrel_container if _parent is BarrelEquipSlotUI else _parent


func _on_item_ui_interact(item_ui: ItemUI, data: BarrelDataResource) -> void:
	super(item_ui, data)
	
	if item_ui.is_locked:
		return
	
	var focus_area_callable: Callable = get_equip_slot_focus.bind(active_equip_idx)
	
	# Equipped barrel slot UI
	if item_ui.is_equipped:
		var _warning_text = GameManager.remove_barrel(data.barrel_id)
		SoundManager.play_ui_sound(sfx_barrel_equip, "UI")
		
		item_ui.empty_slot()
		barrel_info_region.show_barrel_overview(false)
		
		# After removing barrel, keep equip idx the same so we can immediately
		# install an inventory barrel if we want.
		# Otherwise we can cancel to go back.
		var equip_ui: ItemUI = equip_barrel_container.get_child(active_equip_idx).item_ui
		active_focus_idx = active_equip_idx
		clear_item_ui_highlight(equip_ui)
		current_selected_item_ui = null
	
	# Empty equip slot UI
	elif item_ui.is_empty:
		# Change focus to Inventory barrels
		focus_area_callable = get_inventory_focus
		active_equip_idx = item_ui.get_parent().get_index()
		persist_item_ui_highlight(item_ui)
		_desaturate_siblings(item_ui)
	
	# Inventory slot UI
	else:
		# Check we're not overwriting an existing barrel
		var equip_ui: ItemUI = equip_barrel_container.get_child(active_equip_idx).item_ui
		if not equip_ui.is_empty:
			GameManager.remove_barrel(equip_ui.data.barrel_id)
		
		var _warning_text = GameManager.equip_barrel(data.barrel_id, active_equip_idx)
		SoundManager.play_ui_sound(sfx_barrel_equip, "UI")
		
		# After installing a barrel, remove equip idx so we can move between equip slots
		equip_ui = equip_barrel_container.get_child(active_equip_idx).item_ui
		clear_item_ui_highlight(equip_ui)
		_reset_sibling_saturation(equip_ui)
		active_equip_idx = -1
	
	full_refresh_ui(focus_area_callable)


func _on_effect_detail_focus_gained(ui: BarrelInfoIcon) -> void:
	active_effect_detail_idx = ui.get_index()
	barrel_info_region.set_effect_detail_data(active_effect_detail_idx)
 
