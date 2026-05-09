extends Control
class_name InventoryUI

signal inventory_opened
signal inventory_closed
signal reset_barrel_info

@export var barrel_item_ui_prefab: PackedScene
@export var gun_frame_item_ui_prefab: PackedScene
# SFX
@export var sfx_open: AudioStream
@export var sfx_click: AudioStream
@export var sfx_purchase: AudioStream
@export var sfx_too_expensive: AudioStream
@export var sfx_barrel_equip: AudioStream
@export var current_gun_frame_icon: TextureRect
#
@export var scroll_container: ScrollContainer

const CONTROLLER_SCROLL_SPEED_COOEFFICIENT = 3.0

var current_focus_area: Control = null
var current_selected_item_ui: Control = null
@export var barrel_info_region: BarrelInfoRegion = null
var ui_transitioning: bool = false

var active_focus_idx: int = -1
var active_effect_detail_idx: int = -1


func _ready() -> void:
	GameManager.currency_changed.connect(full_refresh_ui.unbind(1))
	GameManager.refresh_shop_ui.connect(full_refresh_ui)
	Input.joy_connection_changed.connect(_on_controller_connection)


func _input(event: InputEvent) -> void:
	if visible:
		if event.is_action_pressed("interact") or \
		event.is_action_pressed("ui_cancel"):
			close()
			get_viewport().set_input_as_handled()
			return


func _process(delta: float) -> void:
	if not visible:
		return
	
	handle_controller_scrolling()


func toggle():
	SoundManager.play_sound(sfx_open, "SFX")
	await close() if visible else await open()


func open():
	GameManager.player.controls_disabled = true
	GameManager.change_fmod_bgm_menu_is_up(true)
	GameManager.player.toggle_anim_reticle(false)
	GameManager.gun_customize_ui = self
	full_refresh_ui(get_first_item_for_focus, true)
	visible = true
	
	_on_controller_connection(0, GameManager.is_controller_connected)
	GameManager.player.is_in_menu = true
	inventory_opened.emit()
	
	# We need to wait a frame so the button doesn't drop focus
	await get_tree().process_frame
	get_first_item_for_focus().grab_focus.call_deferred()


func close():
	GameManager.player.controls_disabled = false
	GameManager.change_fmod_bgm_menu_is_up(false)
	GameManager.player.toggle_anim_reticle(true)
	GameManager.player.is_in_menu = false
	GameManager.gun_customize_ui = null
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	visible = false
	
	inventory_closed.emit()


func full_refresh_ui(focus_area_callable: Callable, forced: bool = false) -> void:
	push_error("method not overriden")


func get_first_item_for_focus() -> Control:
	push_error("method not overriden")
	return null


func handle_controller_scrolling() -> void:
	var controller_scroll_y = Input.get_axis("controller_scroll_up", "controller_scroll_down")
	if abs(controller_scroll_y) < GameManager.controller_deadzone:
		return
	
	scroll_container.scroll_vertical += controller_scroll_y * CONTROLLER_SCROLL_SPEED_COOEFFICIENT
	scroll_container.scroll_vertical = clamp(
		scroll_container.scroll_vertical, 0, 
		scroll_container.get_v_scroll_bar().max_value
	)


## FOCUS HELPERS

func set_focus_neighbour_wrapping(ui_container: Control) -> void:
	var inv_container_count: int = ui_container.get_child_count()
	var _wrap_focus = func(x: int): return wrapi(x, 0, inv_container_count)
	var cols: int = ui_container.columns
	
	for i in range(inv_container_count):
		var inv_ui: Control = ui_container.get_child(i)
		# LEFT
		var prev_inv_idx: int = _wrap_focus.call(i - 1)
		var prev_inv: Control = ui_container.get_child(prev_inv_idx)
		inv_ui.button.focus_neighbor_left = prev_inv.button.get_path()
		# RIGHT
		var next_inv_idx: int = _wrap_focus.call(i + 1)
		var next_inv: Control = ui_container.get_child(next_inv_idx)
		inv_ui.button.focus_neighbor_right = next_inv.button.get_path()
		# UP
		var up_inv_idx = _wrap_focus.call(i - cols)
		if abs(up_inv_idx - i) == cols:
			var up_inv: Control = ui_container.get_child(up_inv_idx)
			inv_ui.button.focus_neighbor_top = up_inv.button.get_path()
		else:
			inv_ui.button.focus_neighbor_top = inv_ui.button.get_path()
		# DOWN
		var down_inv_idx = _wrap_focus.call(i + cols)
		if abs(down_inv_idx - i) == cols:
			var down_inv: Control = ui_container.get_child(down_inv_idx)
			inv_ui.button.focus_neighbor_bottom = down_inv.button.get_path()
		else:
			inv_ui.button.focus_neighbor_bottom = inv_ui.button.get_path()


func set_region_focus_neighbor(a: Control, b: Control, side: Side, one_way: bool = false) -> void:
	if a.get_child_count() == 0 or b.get_child_count() == 0:
		return
	match side:
		Side.SIDE_TOP:
			for i in range(0, a.columns):
				var top_ui: Control = a.get_child(i)
				if not top_ui:
					continue
				var focus_neighbor: NodePath = b.get_child(0).button.get_path()
				top_ui.button.focus_neighbor_top = focus_neighbor
				
				if not one_way:
					set_region_focus_neighbor(b, a, Side.SIDE_BOTTOM, true)
		Side.SIDE_BOTTOM:
			for i in range(-1, -a.columns - 1, -1):
				var bottom_ui: Control = a.get_child(i)
				if not bottom_ui:
					continue
				var focus_neighbor: NodePath = b.get_child(0).button.get_path()
				bottom_ui.button.focus_neighbor_bottom = focus_neighbor
				
				if not one_way:
					set_region_focus_neighbor(b, a, Side.SIDE_TOP, true)


func toggle_ui_focus_neighbors(ui: Control, is_enabled: bool = true) -> void:
	for neighbor in [ui.focus_neighbor_left, ui.focus_neighbor_right, ui.focus_neighbor_top, ui.focus_neighbor_bottom]:
		if neighbor:
			var node = get_node(neighbor)
			if node:
				node.focus_mode = FocusMode.FOCUS_ALL if is_enabled else FocusMode.FOCUS_NONE


## VISUAL MODIFIERS

func clear_item_ui_highlight(ui: Control) -> void:
	ui.is_active_equip = false
	ui.clicked_once = false
	ui.deselect()
	ui.return_button_size()
	ui.button.remove_theme_stylebox_override("normal")
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
	
	ui.modulate = Color("#ffffff")
	
	for item in parent.get_children():
		if item is BarrelEquipSlotUI:
			if item.item_ui == ui:
				continue
			item.item_ui.modulate = Color("#4d4d4d")
			clear_item_ui_highlight(item.item_ui)
		elif item is ItemUI:
			if item == ui:
				continue
			item.modulate = Color("#4d4d4d")
			clear_item_ui_highlight(item)


func _reset_sibling_saturation(ui: Control) -> void:
	var parent = ui.get_parent()
	if parent is BarrelEquipSlotUI:
		parent = parent.get_parent()
	
	for item in parent.get_children():
		if item is BarrelEquipSlotUI:
			item.item_ui.modulate = Color("#ffffff")
			clear_item_ui_highlight(item.item_ui)
		elif item is ItemUI:
			item.modulate = Color("#ffffff")
			clear_item_ui_highlight(item)


#### ITEM UI Callbacks

func _on_item_ui_select(item_ui: ItemUI, data: BarrelDataResource) -> void:
	SoundManager.play_ui_sound(sfx_click, "UI")
	
	if current_selected_item_ui != null:
		current_selected_item_ui.deselect()
	current_selected_item_ui = item_ui
	
	active_focus_idx = item_ui.get_index()
	
	_desaturate_siblings(item_ui)
	
	if item_ui.is_locked:
		barrel_info_region.set_barrel_overview_data(data, true)
		return


func _on_item_ui_button_pressed(ui: Control) -> void:
	push_error("method not overriden")


func _on_item_ui_button_focus_gained(ui: ItemUI) -> void:
	# Farm these out so we can override the sub-methods in child classes
	current_focus_area = _get_current_focus_area_on_button_focus(ui)
	active_focus_idx = _get_active_focus_idx_on_button_focus(ui)
	if ui is BarrelItemUI:
		update_barrel_info(ui.data, ui.is_locked)
	elif ui is GunFrameItemUI:
		# TODO
		pass

func _get_active_focus_idx_on_button_focus(ui: ItemUI) -> int:
	return ui.get_index()

func _get_current_focus_area_on_button_focus(ui: ItemUI) -> Control:
	return ui.get_parent()

func update_barrel_info(data: BarrelDataResource = null, is_locked: bool = false) -> void:
	if data:
		barrel_info_region.populate_detail_circle_ui(data)
		barrel_info_region.set_effect_detail_data(active_effect_detail_idx)
		barrel_info_region.set_barrel_overview_data(data, is_locked)
		
		if barrel_info_region.single_effect_detail.visible and not is_locked:
			barrel_info_region.show_effect_detail()
		else:
			barrel_info_region.show_barrel_overview(true, is_locked)
	else:
		if current_selected_item_ui:
			return
		barrel_info_region.show_barrel_overview(false, is_locked)


func _on_item_ui_button_focus_lost(button: Button) -> void:
	var lost_focus_parent: Control = button.get_parent()
	var focused_ui: Control = current_focus_area.get_child(active_focus_idx) if current_focus_area else null
	# When the mouse leaves an ItemUI:
	#  - if nothing is currently selected in the equip or inventory areas, 
	#      show an empty barrel overview.
	if current_selected_item_ui == null or current_selected_item_ui.is_empty:
		if lost_focus_parent is BarrelItemUI:
			# TODO - track last detail/overview toggle state so we can keep on the detail view between items
			barrel_info_region.show_barrel_overview(false)
		elif lost_focus_parent is GunFrameItemUI:
			# TODO - gun frame overview
			pass
	#  - if an ItemUI is selected and not empty, change the data to the 
	#       ItemUI barrel and keep showing either the overview or the effect detail
	#       - whichever is already open.
	elif not current_selected_item_ui.is_empty:
		# FIXME - add better handling for BarrelItemUI vs GunFrameItemUI overview display
		if lost_focus_parent is BarrelItemUI and current_selected_item_ui is not GunFrameItemUI:
			barrel_info_region.populate_detail_circle_ui(current_selected_item_ui.data)
			barrel_info_region.set_effect_detail_data(active_effect_detail_idx)
			barrel_info_region.set_barrel_overview_data(current_selected_item_ui.data, current_selected_item_ui.is_locked)
			barrel_info_region.show_barrel_overview(true, current_selected_item_ui.is_locked)
		elif lost_focus_parent is GunFrameItemUI:
			# TODO - gun frame overview
			pass
	
	toggle_ui_focus_neighbors(button, true)


func _on_item_ui_interact(item_ui: ItemUI, data: BarrelDataResource) -> void:
	current_selected_item_ui = null
	_reset_sibling_saturation(item_ui)

func _on_gun_frame_item_ui_select(gun_frame_item_ui: GunFrameItemUI, _data: GunFrameResource) -> void:
	push_error("method not overriden")


func _on_gun_frame_item_ui_interact(gun_frame_item_ui: GunFrameItemUI, data: GunFrameResource) -> void:
	push_error("method not overriden")


####

func play_hover_sfx():
	SoundManager.play_button_hover_sfx()


#### util signal methods

func _on_controller_connection(_device: int, connected: bool):
	if self.visible:
		if connected:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
