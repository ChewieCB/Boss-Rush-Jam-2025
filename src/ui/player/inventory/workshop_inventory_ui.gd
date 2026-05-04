extends InventoryUI
class_name WorkshopInventoryUI

@export var equip_barrel_container: HBoxContainer
@export var inventory_gun_frame_container: EquippedFrameSideViewUI 
@export var inventory_normal_barrel_container: GridContainer

var active_equip_idx: int = -1
var active_focus_idx: int = -1
var active_effect_detail_idx: int = -1

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
		
		if event.is_action_pressed("inv_ui_tab_left"):
			get_viewport().set_input_as_handled()
			if equipped_ui.item_ui.clicked_once:
				move_equip_slot(active_equip_idx, -1)
			else:
				change_gun_frame(-1)
				var focus_area = get_equip_slot_focus.bind(active_focus_idx)
				full_refresh_ui(focus_area)
				inventory_gun_frame_container.set_frame_icons(
					GameManager.equipped_gun_frame, 
					available_gun_frames,
					Vector2.LEFT 
				)
			
		elif event.is_action_pressed("inv_ui_tab_right"):
			get_viewport().set_input_as_handled()
			if equipped_ui.item_ui.clicked_once:
				move_equip_slot(active_equip_idx, 1)
			else:
				change_gun_frame(1)
				var focus_area = get_equip_slot_focus.bind(active_focus_idx)
				full_refresh_ui(focus_area)
				inventory_gun_frame_container.set_frame_icons(
					GameManager.equipped_gun_frame, 
					available_gun_frames,
					Vector2.RIGHT 
				)
		
		# TODO - these two should have dedicated functions for ease of debugging
		if event.is_action_pressed("inv_show_barrel_detail"):
			var data: BarrelDataResource
			var _ui: ItemUI
			if focused_ui is ItemUI:
				data = focused_ui.data
				_ui = focused_ui
			elif focused_ui is BarrelEquipSlotUI:
				data = focused_ui.item_ui.data
				_ui = focused_ui.item_ui
			elif focused_ui is GunFrameItemUI:
				return
			
			if _ui.is_empty:
				return
			
			barrel_info_region.show_effect_detail()
			
			if focused_ui.get_parent() is BarrelEquipSlotUI:
				active_focus_idx = focused_ui.get_parent().get_index()
			else:
				active_focus_idx = focused_ui.get_index()
			
			if data:
				barrel_info_region.populate_detail_circle_ui(data)
				barrel_info_region.set_effect_detail_data(0)
				persist_item_ui_highlight(_ui)
				# FIXME - clean this up
				if focused_ui is BarrelEquipSlotUI:
					_desaturate_siblings(focused_ui.item_ui)
				else:
					_desaturate_siblings(focused_ui)
				toggle_ui_focus_neighbors(_ui.button, false)
				var detail_focus: Control = get_barrel_detail_focus(active_effect_detail_idx)
				detail_focus.grab_focus.call_deferred()
				
		elif event.is_action_released("inv_show_barrel_detail"):
			var _ui: ItemUI = focused_ui.item_ui if focused_ui is BarrelEquipSlotUI else focused_ui
			if _ui.is_empty:
				return
			
			barrel_info_region.show_barrel_overview()
			active_effect_detail_idx = -1
			clear_item_ui_highlight(_ui)
			_reset_sibling_saturation(focused_ui)
			toggle_ui_focus_neighbors(_ui.button, true)
			match current_focus_area:
				equip_barrel_container:
					get_equip_slot_focus(active_focus_idx).grab_focus.call_deferred()
				inventory_normal_barrel_container:
					get_inventory_focus(active_focus_idx).grab_focus.call_deferred()
		
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
	_reset_sibling_saturation(focused_ui)
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
	
	get_viewport().set_input_as_handled()
	full_refresh_ui(cancel_focus)

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
	effect_detail_items.pop_front()  # Remove the circle itself
	
	# Update focus area modes
	for slot in equip_barrel_container.get_children():
		slot.item_ui.button.focus_mode = FocusMode.FOCUS_NONE
	for item in effect_detail_items:
		item.focus_mode = FocusMode.FOCUS_ALL
	
	if effect_detail_items:
		if idx != -1:
			return effect_detail_items[idx + 1]
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
	equip_barrel_container.get_child(active_equip_idx).item_ui._on_button_pressed()
	get_viewport().set_input_as_handled()


func change_gun_frame(idx_diff: int) -> void:
	var current_idx: int = available_gun_frames.find(GameManager.equipped_gun_frame)
	var new_idx: int = wrapi(current_idx + idx_diff, 0, available_gun_frames.size())
	var new_frame = available_gun_frames[new_idx]
	var warning_text = GameManager.equip_gun_frame(new_frame.frame_id)
	show_warning(warning_text)
	SoundManager.play_ui_sound(sfx_barrel_equip, "UI")


#### Highlight/Focus helpers

func clear_item_ui_highlight(ui: ItemUI) -> void:
	super(ui)
	toggle_ui_focus_neighbors(ui.button, true)


func persist_item_ui_highlight(ui: Control) -> void:
	ui.is_active_equip = true
	ui.border_selected.visible = true
	ui.button.add_theme_stylebox_override(
		"normal",
		ui.button.get_theme_stylebox("focus", "Button")
	)


func _desaturate_siblings(ui: Control) -> void:
	var parent = ui.get_parent()
	if not parent:
		return
	if parent is BarrelEquipSlotUI:
		parent = parent.get_parent()
	
	for item in parent.get_children():
		if item is BarrelEquipSlotUI:
			if item.item_ui == ui:
				continue
			item.item_ui.modulate = Color("#4d4d4d")
		else:
			if item == ui:
				continue
			item.modulate = Color("#4d4d4d")


func _reset_sibling_saturation(ui: Control) -> void:
	var parent = ui.get_parent()
	if parent is BarrelEquipSlotUI:
		parent = parent.get_parent()
	
	for item in parent.get_children():
		if item is BarrelEquipSlotUI:
			item.item_ui.modulate = Color("#ffffff")
		else:
			item.modulate = Color("#ffffff")


func toggle_ui_focus_neighbors(ui: Control, is_enabled: bool = true) -> void:
	for neighbor in [ui.focus_neighbor_left, ui.focus_neighbor_right, ui.focus_neighbor_top, ui.focus_neighbor_bottom]:
		if neighbor:
			var node = get_node(neighbor)
			if node:
				node.focus_mode = FocusMode.FOCUS_ALL if is_enabled else FocusMode.FOCUS_NONE


#### Signal Callbacks

func _on_item_ui_select(ui: ItemUI, data: BarrelDataResource) -> void:
	SoundManager.play_ui_sound(sfx_click, "UI")
	
	if current_selected_item_ui != null:
		current_selected_item_ui.deselect()
	current_selected_item_ui = ui
	
	active_focus_idx = ui.get_index()
	
	_desaturate_siblings(ui)
	
	if ui.is_locked:
		barrel_info_region.show_barrel_locked()
		return


func _on_item_ui_button_pressed(ui: Control) -> void:
	if ui.clicked_once:
		active_focus_idx = ui.get_index()
	if ui.is_equipped or ui.is_empty:
		active_equip_idx = ui.get_parent().get_index()
	# Remove focus neighbors
	toggle_ui_focus_neighbors(ui, false)


func _on_item_ui_button_focus_gained(ui: ItemUI) -> void:
	var _parent: Control = ui.get_parent()
	current_focus_area = equip_barrel_container if _parent is BarrelEquipSlotUI else _parent
	active_focus_idx = _parent.get_index() if _parent is BarrelEquipSlotUI else ui.get_index()
	
	if ui.data:
		barrel_info_region.set_barrel_overview_data(ui.data)
		barrel_info_region.populate_detail_circle_ui(ui.data)
		if Input.is_action_pressed("inv_show_barrel_detail"):
			barrel_info_region.show_effect_detail()
			barrel_info_region.set_effect_detail_data(active_effect_detail_idx)
		else:
			barrel_info_region.show_barrel_overview()


func _on_item_ui_button_focus_lost(button: Button) -> void:
	toggle_ui_focus_neighbors(button, true)


func _on_item_ui_interact(item_ui: ItemUI, data: BarrelDataResource) -> void:
	current_selected_item_ui = null
	
	_reset_sibling_saturation(item_ui)
	
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
		var warning_text = GameManager.equip_barrel(data.barrel_id, active_equip_idx)
		SoundManager.play_ui_sound(sfx_barrel_equip, "UI")
		show_warning(warning_text)
		
		# After installing a barrel, remove equip idx so we can move between equip slots
		var equip_ui: ItemUI = equip_barrel_container.get_child(active_equip_idx).item_ui
		clear_item_ui_highlight(equip_ui)
		_reset_sibling_saturation(equip_ui)
		active_equip_idx = -1
	
	full_refresh_ui(focus_area_callable)


func _on_effect_detail_focus_gained(ui: BarrelInfoIcon) -> void:
	active_effect_detail_idx = ui.get_index()  # - 1  # Offset since the circle texture is a sibling node
	barrel_info_region.set_effect_detail_data(active_effect_detail_idx)
 
