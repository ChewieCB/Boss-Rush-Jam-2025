extends Control

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		return_to_main_menu()

func return_to_main_menu():
	SoundManager.play_button_click_sfx()
	if GameManager.chosen_slot_id != -1:
		GameManager.update_total_playtime()
		await SaveManager.save_game(GameManager.chosen_slot_id)
	GameManager.reset_current_save_data()
	SaveManager.save_data_is_loaded = false
	
	## TODO - background loading here
	LoadingHandler.current_scene_path = "res://src/ui/main_menu/MainMenu.tscn"
	LoadingHandler.start_loading("Main Menu")
	# Toggle low pass filter for BGM
	await LoadingHandler.loading_finished
	AudioServer.set_bus_effect_enabled(1, 0, false)