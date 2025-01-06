extends Control
class_name PauseUI

@onready var pause_option_list: Control = $PauseOptionBG
@onready var setting_ui: SettingUI = $SettingUI

var is_paused = false
var is_in_submenu = false


func _ready() -> void:
	GameManager.pause_ui = self
	visible = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu"):
		if is_in_submenu:
			setting_ui.close_menu()
			SoundManager.play_button_click_sfx()
			return_to_pause_menu()
		else:
			SoundManager.play_button_click_sfx()
			is_paused = not is_paused
			get_tree().paused = is_paused
			visible = is_paused
			if is_paused:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func return_to_pause_menu():
	is_in_submenu = false
	pause_option_list.visible = true


func _on_setting_button_pressed() -> void:
	setting_ui.open_menu()
	is_in_submenu = true
	pause_option_list.visible = false
	SoundManager.play_button_click_sfx()


func _on_exit_button_pressed() -> void:
	SoundManager.play_button_click_sfx()
	get_tree().quit()


func _on_exit_button_mouse_entered() -> void:
	SoundManager.play_button_hover_sfx()


func _on_setting_button_mouse_entered() -> void:
	SoundManager.play_button_hover_sfx()
