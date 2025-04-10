extends Control
class_name PauseUI

@onready var pause_option_list: Control = $PauseOptionBG
@onready var setting_ui: SettingUI = $SettingUI

var is_paused = false
var is_in_submenu = false


func _ready() -> void:
	GameManager.pause_ui = self
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu"):
		if is_in_submenu:
			setting_ui.close_menu()
			SoundManager.play_button_click_sfx()
			return_to_pause_menu()
		else:
			SoundManager.play_button_click_sfx()
			# TODO - fix this to be generic across all inventory UIs
			#GameManager.player.inventory_ui.close()
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


func _on_lobby_button_pressed() -> void:
	SoundManager.play_button_click_sfx()
	#ScreenTransition.transition_out()
	#await ScreenTransition.transition_finished
	# TODO - background loading here
	LoadingHandler.current_scene_path = "res://src/maps/lobby/Lobby.tscn"
	LoadingHandler.start_loading("Lobby")


func _on_main_menu_button_pressed() -> void:
	SoundManager.play_button_click_sfx()
	if GameManager.chosen_slot_id != -1:
		GameManager.update_total_playtime()
		await SaveManager.save_game(GameManager.chosen_slot_id)
	GameManager.reset_current_save_data()
	SaveManager.save_data_is_loaded = false
	
	#ScreenTransition.transition_out()
	#await ScreenTransition.transition_finished
	## TODO - background loading here
	LoadingHandler.current_scene_path = "res://src/ui/main_menu/MainMenu.tscn"
	LoadingHandler.start_loading("Main Menu")


func _on_exit_button_pressed() -> void:
	SoundManager.play_button_click_sfx()
	if GameManager.chosen_slot_id != -1:
		GameManager.update_total_playtime()
		await SaveManager.save_game(GameManager.chosen_slot_id)
	get_tree().quit()


func play_button_hover_sfx():
	SoundManager.play_button_hover_sfx()
