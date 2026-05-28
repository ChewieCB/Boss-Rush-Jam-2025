extends Control
class_name PauseUI

signal pause_ui_toggled
signal ui_accept_pressed

@onready var parent_canvaslayer: CanvasLayer = get_parent()
@onready var pause_option_list: Control = $PauseOptionBG
@onready var setting_button: Button = $PauseOptionBG/VBoxContainer/SettingButton
@onready var setting_ui: SettingUI = $SettingUI
@onready var promo_ui: Control = $QRLinkUI

var is_paused: bool = false
var is_in_submenu: bool = false
var is_controller_connected: bool = false


func _ready() -> void:
	GameManager.pause_ui = self
	visible = false
	Input.joy_connection_changed.connect(_on_controller_connection)
	is_controller_connected = Input.get_connected_joypads() != []
	# Tweak lobby button text if we're in the tutorial
	if not GameManager.tutorial_completed:
		$PauseOptionBG/VBoxContainer/LobbyButton.text = "Restart"
	is_paused = false
	get_tree().paused = false
	

func _unhandled_input(event: InputEvent) -> void:
	# If the pause menu button is pressed, reset the pause menu and hide/show it
	if event.is_action_pressed("pause_menu"):
		SoundManager.play_button_click_sfx()
		toggle_pause_menu()
	elif event.is_action_pressed("ui_cancel"):
		# Handle the input so we don't trigger non UI inputs when closing a menu
		get_viewport().set_input_as_handled()
		# If the UI cancel button is pressed and the settings menu is open, close the settings menu only
		if is_in_submenu:
			# If setting menu is remapping, ignore this
			if setting_ui.is_remapping:
				return
			setting_ui.close_menu()
			SoundManager.play_button_click_sfx()
			return_to_pause_menu()
		# If the UI cancel button is pressed and the pause menu is open, close it
		else:
			if is_paused:
				toggle_pause_menu()
	elif event.is_action_pressed("ui_accept"):
		ui_accept_pressed.emit()


func toggle_pause_menu() -> void:
	is_paused = not is_paused
	parent_canvaslayer.layer = 4 if is_paused else 1
	GameManager.change_fmod_bgm_menu_is_up(is_paused)
	
	get_tree().paused = is_paused
	self.visible = is_paused
	# Reset the pause menu UI
	setting_ui.close_menu()
	return_to_pause_menu()
	
	pause_ui_toggled.emit()
	# Toggle low pass filter for BGM
	AudioServer.set_bus_effect_enabled(1, 0, is_paused)
	# Update mouse capture/control focus
	if is_paused:
		if not is_controller_connected:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			setting_button.grab_focus()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func return_to_pause_menu():
	is_in_submenu = false
	pause_option_list.visible = true
	promo_ui.visible = true
	setting_button.grab_focus()


func _on_setting_button_pressed() -> void:
	promo_ui.visible = false
	setting_ui.open_menu()
	is_in_submenu = true
	pause_option_list.visible = false
	SoundManager.play_button_click_sfx()


func _on_lobby_button_pressed() -> void:
	SoundManager.play_button_click_sfx()
	GameManager.change_fmod_bgm_menu_is_up(false)
	
	parent_canvaslayer.layer = 1
	if not GameManager.tutorial_completed:
		LoadingHandler.start_loading(
			LoadingHandler.level_paths[LoadingHandler.LEVELS.TUTORIAL],
			"Tutorial"
		)
	else:
		LoadingHandler.start_loading(
			LoadingHandler.level_paths[LoadingHandler.LEVELS.BACKROOM],
			"Backroom"
		)
	
	# Toggle low pass filter for BGM
	await ScreenTransition.transition_finished
	AudioServer.set_bus_effect_enabled(1, 0, false)
	LoadingHandler.load_scene_transition()


func _on_main_menu_button_pressed() -> void:
	SoundManager.play_button_click_sfx()
	GameManager.change_fmod_bgm_menu_is_up(false)
	
	if GameManager.chosen_slot_id != -1:
		GameManager.update_total_playtime()
		await SaveManager.save_game(GameManager.chosen_slot_id)
	GameManager.reset_current_save_data()
	SaveManager.save_data_is_loaded = false
	
	## TODO - background loading here
	parent_canvaslayer.layer = 1
	LoadingHandler.start_loading("res://src/ui/main_menu/MainMenu.tscn", "Main Menu")
	# Toggle low pass filter for BGM
	await ScreenTransition.transition_finished
	AudioServer.set_bus_effect_enabled(1, 0, false)
	LoadingHandler.load_scene_transition()


func _on_quit_button_pressed() -> void:
	SoundManager.play_button_click_sfx()
	GameManager.change_fmod_bgm_menu_is_up(false)
	if GameManager.chosen_slot_id != -1:
		GameManager.update_total_playtime()
		await SaveManager.save_game(GameManager.chosen_slot_id)
	
	# TODO - move promo UI to a higher node in the scene tree to avoid this shuffling
	# TODO - add toggle for promo ui for editor testing vs release
	#promo_ui.visible = true
	#remove_child(promo_ui)
	#get_parent().add_child(promo_ui)
	#self.visible = false
	#await get_tree().create_timer(3.0).timeout
	get_tree().quit()


func play_button_hover_sfx():
	SoundManager.play_button_hover_sfx()


func _on_controller_connection(_device: int, connected: bool) -> void:
	is_controller_connected = connected
	if is_paused and not is_controller_connected:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		setting_button.grab_focus()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
