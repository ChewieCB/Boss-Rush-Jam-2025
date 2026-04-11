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
@export var warning_label: Label
@export var scroll_container: ScrollContainer

const CONTROLLER_SCROLL_SPEED_COOEFFICIENT = 3.0

var current_selected_item_ui: Control = null
@export var barrel_info_region: BarrelInfoRegion = null
var ui_transitioning: bool = false


func _ready() -> void:
	GameManager.currency_changed.connect(full_refresh_ui.unbind(1))
	GameManager.refresh_shop_ui.connect(full_refresh_ui)
	Input.joy_connection_changed.connect(_on_controller_connection)
	
	barrel_info_region.reset_ui()
	full_refresh_ui(true)


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
	full_refresh_ui(true)
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


func show_warning(content: String, color: Color = Color.RED) -> void:
	if content.contains("Warning"):
		color = Color.YELLOW
	# FIXME - reimplement warning label UI
	#warning_label.self_modulate = color
	#warning_label.text = content
	#warning_label.visible = true


func full_refresh_ui(forced: bool = false) -> void:
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


#### 
func _on_item_ui_select(item_ui: ItemUI, data: BarrelDataResource) -> void:
	push_error("method not overriden")


func _on_item_ui_interact(item_ui: ItemUI, data: BarrelDataResource) -> void:
	push_error("method not overriden")


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
