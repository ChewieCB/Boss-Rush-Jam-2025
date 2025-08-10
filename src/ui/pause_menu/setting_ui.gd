extends Control
class_name SettingUI

# https://github.com/nathanhoad/godot_input_helper/blob/main/docs/Mapping.md

signal setting_changed
signal setting_back_button_pressed

@export var is_at_main_menu = false
@export var keybind_button_prefab: PackedScene

@onready var tab_container: TabContainer = $TabContainer

@onready var mouse_sen_slider: HSlider = $TabContainer/Control/ScrollContainer/VBoxContainer/MouseSens/MouseSenSlider
@onready var mouse_sen_value: Label = $TabContainer/Control/ScrollContainer/VBoxContainer/MouseSens/Value
@onready var aim_assist_slider: HSlider = $TabContainer/Control/ScrollContainer/VBoxContainer/ControllerAimAssistSens/AimAssistSlider
@onready var aim_assist_value: Label = $TabContainer/Control/ScrollContainer/VBoxContainer/ControllerAimAssistSens/Value
@onready var fov_slider: HSlider = $TabContainer/Graphic/VBoxContainer/FOV/FOVSlider
@onready var fov_value: Label = $TabContainer/Graphic/VBoxContainer/FOV/Value
@onready var camera_tilt_toggle: CheckButton = $TabContainer/Graphic/VBoxContainer/CameraTilt/CameraTiltToggle
@onready var fps_limit_option_button: OptionButton = $TabContainer/Graphic/VBoxContainer/FPSLimit/FPSLimitOptionButton
@onready var vsync_option_button: OptionButton = $TabContainer/Graphic/VBoxContainer/Vsync/VsyncOptionButton
@onready var window_mode_option_button: OptionButton = $TabContainer/Graphic/VBoxContainer/WindowMode/WindowModeOptionButton
@onready var resolution_option_button: OptionButton = $TabContainer/Graphic/VBoxContainer/Resolution/ResolutionOptionButton
@onready var scaling_3d_slider: HSlider = $TabContainer/Graphic/VBoxContainer/Scaling3D/Scaling3DSlider
@onready var scaling_3d_value: Label = $TabContainer/Graphic/VBoxContainer/Scaling3D/Value
@onready var hide_ui_toggle: CheckButton = $TabContainer/Graphic/VBoxContainer/HideUI/HideUIToggle
@onready var hide_hurt_overlay_toggle: CheckButton = $TabContainer/Graphic/VBoxContainer/HideHurtOverlay/HideHurtOverlayToggle
@onready var hide_damage_number_toggle: CheckButton = $TabContainer/Graphic/VBoxContainer/HideDamageNumber/HideDamageNumberToggle


# Accessibility
@onready var screen_shake_toggle: CheckButton = $TabContainer/Graphic/VBoxContainer/ScreenShakeToggle/ScreenShakeToggle
@onready var drunk_blur_toggle: CheckButton = $TabContainer/Graphic/VBoxContainer/DrunkBlurToggle/DrunkBlurToggle


@onready var master_slider: HSlider = $TabContainer/Audio/VBoxContainer/Master/MasterSlider
@onready var master_value: Label = $TabContainer/Audio/VBoxContainer/Master/Value
@onready var bgm_slider: HSlider = $TabContainer/Audio/VBoxContainer/BGM/BGMSlider
@onready var bgm_value: Label = $TabContainer/Audio/VBoxContainer/BGM/Value
@onready var sfx_slider: HSlider = $TabContainer/Audio/VBoxContainer/SFX/SFXSlider
@onready var sfx_value: Label = $TabContainer/Audio/VBoxContainer/SFX/Value
@onready var ui_slider: HSlider = $TabContainer/Audio/VBoxContainer/UI/UISlider
@onready var ui_value: Label = $TabContainer/Audio/VBoxContainer/UI/Value

@onready var tab_header_container: Container = $HBoxContainer
@onready var keybind_container: Control = $TabContainer/Control/ScrollContainer/KeybindingSection/KeybindContainer

@onready var normal_control_options_section: Control = $TabContainer/Control/ScrollContainer/VBoxContainer
@onready var keybinding_control_options_section: Control = $TabContainer/Control/ScrollContainer/KeybindingSection
@onready var edit_keybind_button: Button = $TabContainer/Control/ScrollContainer/VBoxContainer/SetControllerBinding/EditKeybindButton
@onready var keybind_return_button: Button = $TabContainer/Control/ScrollContainer/KeybindingSection/HBoxContainer/KeybindingReturnButton
@onready var keybind_timer: Timer = $KeybindTimer

@export var sfx_free_money: AudioStream
@onready var timescale_slider: HSlider = $TabContainer/DEBUG/VBoxContainer/Timescale/TimescaleSlider
@onready var timescale_value: Label = $TabContainer/DEBUG/VBoxContainer/Timescale/Value

const KEYBIND_TIME_LIMIT = 5

var keybindable_action_list = {
	"move_up": "Move forward",
	"move_down": "Move backward",
	"move_left": "Move left",
	"move_right": "Move right",
	"jump": "Jump",
	"dash": "Dash",
	"crouch": "Crouch/Slam",
	"pause_menu": "Pause",
	"shoot": "Shoot",
	"spin_reload": "Reload",
	"spin_barrels": "Re-roll Barrels",
	"show_detail": "Show Barrel Effects",
	"interact": "Interact",
}
var is_remapping = false
var is_remapping_controller = false
var action_to_remap = null
var remapping_button: KeybindButton = null
var keybind_timer_timeleft = 0

func _ready() -> void:
	GameManager.setting_ui = self
	refresh_setting_value()
	SaveManager.setting_config_loaded.connect(refresh_setting_value)
	normal_control_options_section.visible = true
	keybinding_control_options_section.visible = false
	Input.joy_connection_changed.connect(_on_controller_connection)
	await get_tree().process_frame
	await get_tree().process_frame
	_on_controller_connection(0, GameManager.is_controller_connected)

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if keybinding_control_options_section.visible:
			if not is_remapping:
				normal_control_options_section.visible = true
				keybinding_control_options_section.visible = false
				edit_keybind_button.grab_focus()
				accept_event()
				return

	if is_remapping:
		var did_update = false

		if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
			if not is_remapping_controller:
				InputHelper.set_keyboard_input_for_action(action_to_remap, event, false)
				did_update = true
		elif (event is InputEventJoypadButton or event is InputEventJoypadMotion) and event.is_pressed():
			if is_remapping_controller:
				InputHelper.set_joypad_input_for_action(action_to_remap, event, false)
				did_update = true

		if did_update:
			remapping_button.update_button_detail()
			is_remapping = false
			action_to_remap = null
			remapping_button = null
			accept_event()
		return

	if event.is_action_pressed("ui_page_up"):
		var next_tab_id = tab_container.current_tab + 1
		if next_tab_id > tab_container.get_child_count() - 1:
			next_tab_id = 0
		tab_container.current_tab = next_tab_id
		tab_header_container.get_child(next_tab_id).grab_focus()

	if event.is_action_pressed("ui_page_down"):
		var next_tab_id = tab_container.current_tab - 1
		if next_tab_id < 0:
			next_tab_id = tab_container.get_child_count() - 1
		tab_container.current_tab = next_tab_id
		tab_header_container.get_child(next_tab_id).grab_focus()


func open_menu():
	visible = true
	timescale_slider.value = Engine.time_scale
	timescale_value.text = "{0}".format([Engine.time_scale])

	tab_container.current_tab = 0
	mouse_sen_slider.focus_neighbor_top = $HBoxContainer.get_child(0).get_path()
	tab_header_container.get_child(tab_container.current_tab).grab_focus()
	# Grab focus first element INSIDE the tab container instead of the tab themselve
	var event = InputEventAction.new()
	event.action = "ui_down"
	event.pressed = true
	Input.parse_input_event(event)


func close_menu():
	if remapping_button:
		remapping_button.update_button_detail()
		is_remapping = false
		action_to_remap = null
		remapping_button = null
		accept_event()
	visible = false
	normal_control_options_section.visible = true
	keybinding_control_options_section.visible = false
	SaveManager.save_setting_config()

func _on_control_option_pressed() -> void:
	tab_container.current_tab = 0
	reset_on_tab_changed()
	SoundManager.play_button_click_sfx()

func _on_graphic_option_pressed() -> void:
	tab_container.current_tab = 1
	reset_on_tab_changed()
	SoundManager.play_button_click_sfx()

func _on_audio_option_pressed() -> void:
	tab_container.current_tab = 2
	reset_on_tab_changed()
	SoundManager.play_button_click_sfx()

func _on_debug_option_pressed() -> void:
	tab_container.current_tab = 3
	reset_on_tab_changed()
	SoundManager.play_button_click_sfx()


func _on_back_button_pressed() -> void:
	setting_back_button_pressed.emit()
	SoundManager.play_button_click_sfx()
	close_menu()
	if not is_at_main_menu:
		GameManager.pause_ui.return_to_pause_menu()

func _on_mouse_sen_slider_value_changed(value: float) -> void:
	GameManager.mouse_sensitivity = value
	mouse_sen_value.text = "{0}".format([value])

func _on_aim_assist_slider_value_changed(value: float) -> void:
	GameManager.aim_assist_strength = value / 100.0
	aim_assist_value.text = "{0}".format([value])

func _on_fov_slider_value_changed(value: float) -> void:
	GameManager.camera_fov = value
	fov_value.text = "{0}".format([value])

func _on_camera_tilt_toggle_toggled(toggled_on: bool) -> void:
	SoundManager.play_button_click_sfx()
	GameManager.camera_tilt = toggled_on

func _on_fps_limit_option_button_item_selected(index: int) -> void:
	SoundManager.play_button_click_sfx()
	Engine.max_fps = GameManager.FPS_LIMIT_ARRAY[index]
	GameManager.fps_limit_index = index

func _on_vsync_option_button_item_selected(index: int) -> void:
	SoundManager.play_button_click_sfx()
	DisplayServer.window_set_vsync_mode(index)
	GameManager.vsync_option_index = index

func _on_resolution_option_button_item_selected(index: int) -> void:
	SoundManager.play_button_click_sfx()
	DisplayServer.window_set_size(GameManager.RESOLUTION_ARRAY[index])
	GameManager.resolution_index = index
	centre_window()

func _on_master_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(value / 100.0))
	master_value.text = "{0}".format([value])
	GameManager.master_audio = value

func _on_ui_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(3, linear_to_db(value / 100.0))
	ui_value.text = "{0}".format([value])
	GameManager.ui_audio = value

func _on_sfx_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(2, linear_to_db(value / 100.0))
	sfx_value.text = "{0}".format([value])
	GameManager.sfx_audio = value

func _on_bgm_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(1, linear_to_db(value / 100.0))
	bgm_value.text = "{0}".format([value])
	GameManager.bgm_audio = value

func play_button_hover_sfx():
	SoundManager.play_button_hover_sfx()

func set_window_mode(index: int) -> void:
	# Hack workaround to fix crash on mac, figure out a better solution maybe
	if OS.get_name() == "macOS":
		if index == 2:
			index = 1
	match index:
		0: # Fullscreen
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			resolution_option_button.disabled = true
			var resolution_text = str(get_window().get_size().x) + "x" + str(get_window().get_size().y)
			resolution_option_button.set_text(resolution_text)
		1: # Windowed
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_size(GameManager.RESOLUTION_ARRAY[GameManager.resolution_index])
			centre_window()
			resolution_option_button.disabled = false
			resolution_option_button.selected = GameManager.resolution_index
		2: # Borderless windowed
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			DisplayServer.window_set_size(GameManager.RESOLUTION_ARRAY[GameManager.resolution_index])
			centre_window()
			resolution_option_button.disabled = false
			resolution_option_button.selected = GameManager.resolution_index

func centre_window():
	var centre_screen = DisplayServer.screen_get_position() + DisplayServer.screen_get_size() / 2
	var window_size = get_window().get_size_with_decorations()
	get_window().set_position(centre_screen - window_size / 2)

func _on_window_mode_option_button_item_selected(index: int) -> void:
	set_window_mode(index)
	GameManager.window_mode_index = index

func _on_scaling_3d_slider_value_changed(value: float) -> void:
	GameManager.scaling_3d = value
	get_viewport().set_scaling_3d_scale(value / 100.0)
	scaling_3d_value.text = "{0}%".format([value])

func create_keybind_buttons():
	for child in keybind_container.get_children():
		child.queue_free()
	for action in keybindable_action_list:
		var button_inst: KeybindButton = keybind_button_prefab.instantiate()
		keybind_container.add_child(button_inst)
		button_inst.setting_ui = self
		button_inst.action_label.text = keybindable_action_list[action]
		button_inst.assigned_action_name = action
		button_inst.update_button_detail()
		button_inst.kbm_button.pressed.connect(_on_input_button_pressed.bind(button_inst, action, false))
		button_inst.kbm_button.mouse_entered.connect(play_button_hover_sfx)
		button_inst.controller_button.pressed.connect(_on_input_button_pressed.bind(button_inst, action, true))
		button_inst.controller_button.mouse_entered.connect(play_button_hover_sfx)


func _on_input_button_pressed(button: KeybindButton, action: String, is_controller: bool):
	if not is_remapping:
		is_remapping = true
		is_remapping_controller = is_controller
		action_to_remap = action
		remapping_button = button
		keybind_timer_timeleft = KEYBIND_TIME_LIMIT
		remapping_button.set_changing_keybind_text("Press key to bind ({0})...".format([keybind_timer_timeleft]), is_remapping_controller)
		keybind_timer.start()


func _on_hide_ui_toggled(toggled_on: bool) -> void:
	SoundManager.play_button_click_sfx()
	GameManager.hide_ui = toggled_on
	setting_changed.emit()

func _on_hide_hurt_overlay_toggle_toggled(toggled_on: bool) -> void:
	SoundManager.play_button_click_sfx()
	GameManager.hide_hurt_overlay = toggled_on
	setting_changed.emit()


func _on_hide_damage_number_toggle_toggled(toggled_on: bool) -> void:
	SoundManager.play_button_click_sfx()
	GameManager.hide_damage_number = toggled_on
	setting_changed.emit()

func _on_screen_shake_toggle_toggled(toggled_on: bool) -> void:
	SoundManager.play_button_click_sfx()
	GameManager.screen_shake_disabled = !toggled_on
	setting_changed.emit()
	GameManager.setting_changed.emit()


func _on_drunk_blur_toggle_toggled(toggled_on: bool) -> void:
	SoundManager.play_button_click_sfx()
	GameManager.drunk_blur_disabled = !toggled_on
	setting_changed.emit()
	GameManager.setting_changed.emit()


func refresh_setting_value():
	mouse_sen_slider.value = GameManager.mouse_sensitivity
	mouse_sen_value.text = "{0}".format([GameManager.mouse_sensitivity])

	aim_assist_slider.value = GameManager.aim_assist_strength * 100
	aim_assist_value.text = "{0}".format([GameManager.aim_assist_strength * 100])

	fov_slider.value = GameManager.camera_fov
	fov_value.text = "{0}".format([GameManager.camera_fov])

	camera_tilt_toggle.set_pressed_no_signal(GameManager.camera_tilt)
	hide_ui_toggle.set_pressed_no_signal(GameManager.hide_ui)
	hide_hurt_overlay_toggle.set_pressed_no_signal(GameManager.hide_hurt_overlay)
	hide_damage_number_toggle.set_pressed_no_signal(GameManager.hide_damage_number)
	screen_shake_toggle.set_pressed_no_signal(!GameManager.screen_shake_disabled)
	drunk_blur_toggle.set_pressed_no_signal(!GameManager.drunk_blur_disabled)

	Engine.max_fps = GameManager.FPS_LIMIT_ARRAY[GameManager.fps_limit_index]
	fps_limit_option_button.selected = GameManager.fps_limit_index

	DisplayServer.window_set_vsync_mode(GameManager.vsync_option_index)
	vsync_option_button.selected = GameManager.vsync_option_index

	DisplayServer.window_set_size(GameManager.RESOLUTION_ARRAY[GameManager.resolution_index])
	resolution_option_button.selected = GameManager.resolution_index

	set_window_mode(GameManager.window_mode_index)
	window_mode_option_button.selected = GameManager.window_mode_index

	get_viewport().set_scaling_3d_scale(GameManager.scaling_3d / 100.0)
	scaling_3d_slider.value = GameManager.scaling_3d
	scaling_3d_value.text = "{0}%".format([GameManager.scaling_3d])

	# TODO - update these to use the more recent SoundManager version (or downgrade SoundManager)
	#SoundManager.set_master_volume(GameManager.master_audio / 100.0)
	#SoundManager.set_music_volume(GameManager.bgm_audio / 100.0)
	#SoundManager.set_sound_volume(GameManager.sfx_audio / 100.0)
	#SoundManager.set_ui_sound_volume(GameManager.ui_audio / 100.0)
	master_slider.value = GameManager.master_audio
	master_value.text = "{0}".format([GameManager.master_audio])
	bgm_slider.value = GameManager.bgm_audio
	bgm_value.text = "{0}".format([GameManager.bgm_audio])
	sfx_slider.value = GameManager.sfx_audio
	sfx_value.text = "{0}".format([GameManager.sfx_audio])
	ui_slider.value = GameManager.ui_audio
	ui_value.text = "{0}".format([GameManager.ui_audio])

	timescale_slider.value = Engine.time_scale
	timescale_value.text = "{0}".format([Engine.time_scale])


func reset_on_tab_changed():
	normal_control_options_section.visible = true
	keybinding_control_options_section.visible = false


func _on_keybind_default_button_pressed() -> void:
	InputHelper.reset_all_actions()
	create_keybind_buttons()


func _on_keybinding_return_button_pressed() -> void:
	normal_control_options_section.visible = true
	keybinding_control_options_section.visible = false
	edit_keybind_button.grab_focus()


func _on_edit_keybind_button_pressed() -> void:
	create_keybind_buttons()
	normal_control_options_section.visible = false
	keybinding_control_options_section.visible = true
	keybind_return_button.grab_focus()

func _on_keybind_timer_timeout() -> void:
	keybind_timer_timeleft -= 1
	if keybind_timer_timeleft <= 0:
		# Stop keybinding process
		keybind_timer.stop()
		if remapping_button:
			remapping_button.update_button_detail()
			is_remapping = false
			action_to_remap = null
			remapping_button = null
			accept_event()
	else:
		# Countdown
		if remapping_button:
			remapping_button.set_changing_keybind_text("Press key to bind ({0})...".format([keybind_timer_timeleft]), is_remapping_controller)


func _on_controller_connection(_device: int, connected: bool):
	# Disable aim assist and it's options if no controller is detected
	if not connected:
		aim_assist_slider.value = 0
		aim_assist_value.text = "Disabled"
		aim_assist_slider.editable = false
		if aim_assist_slider.is_connected("value_changed", _on_aim_assist_slider_value_changed):
			aim_assist_slider.value_changed.disconnect(_on_aim_assist_slider_value_changed)
	else:
		aim_assist_slider.value = GameManager.aim_assist_strength * 100
		aim_assist_value.text = "{0}".format([GameManager.aim_assist_strength * 100])
		aim_assist_slider.editable = true
		if not aim_assist_slider.is_connected("value_changed", _on_aim_assist_slider_value_changed):
			aim_assist_slider.value_changed.connect(_on_aim_assist_slider_value_changed)

	if keybinding_control_options_section.visible:
		create_keybind_buttons()


func _on_tab_container_tab_changed(tab: int) -> void:
	mouse_sen_slider.focus_neighbor_top = tab_header_container.get_child(tab).get_path()
	fov_slider.focus_neighbor_top = tab_header_container.get_child(tab).get_path()
	master_slider.focus_neighbor_top = tab_header_container.get_child(tab).get_path()


func _on_boss_one_shot_toggle_toggled(toggled_on: bool) -> void:
	SoundManager.play_button_click_sfx()
	GameManager.CHEAT_oneshot = toggled_on


func _on_gode_mode_toggle_toggled(toggled_on: bool) -> void:
	SoundManager.play_button_click_sfx()
	GameManager.CHEAT_godmode = toggled_on


func _on_freecam_toggle_toggled(toggled_on: bool) -> void:
	SoundManager.play_button_click_sfx()
	GameManager.CHEAT_freecam = toggled_on


func _on_timescale_slider_value_changed(value: float) -> void:
	Engine.time_scale = value
	timescale_value.text = "{0}".format([value])


func _on_free_money_button_pressed() -> void:
	GameManager.player_currency += 1000
	SoundManager.play_ui_sound(sfx_free_money)
