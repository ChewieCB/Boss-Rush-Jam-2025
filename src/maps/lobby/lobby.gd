extends Node3D

@export var bgm: AudioStream
@onready var lobby_music_player: AudioStreamPlayer3D = $LobbyMusicPlayer

signal ui_accept

@onready var elevator_doors: ElevatorDoors = find_children("*", "ElevatorDoors").front()
@onready var elevator_buttons: Array[Node] = find_children("*", "ElevatorButton")

@onready var tutorial_ui: Control = $UI/TutorialUI
@onready var game_win_ui: Control = $UI/GameWinUI

var display_barrels: Array = []

func _ready() -> void:
	ScreenTransition.fill_screen()
	
	Engine.time_scale = 1
	SoundManager.stop_music(0.1)
	for button in elevator_buttons:
		button.pushed.connect(_on_level_select)
	get_tree().paused = false
	
	ScreenTransition.transition_in()
	await ScreenTransition.transition_finished
	
	lobby_music_player.play()

	# Save and load check
	if SaveManager.save_data_is_loaded:
		GameManager.update_total_playtime()
		SaveManager.save_game(GameManager.chosen_slot_id)
	else:
		# First time get to lobby, load data from save file
		GameManager.start_record_playtime()
		SaveManager.load_game(GameManager.chosen_slot_id)


	# HACK
	if GameManager.player_gained_first_barrel:
		if not GameManager.barrel_tutorial_shown:
			tutorial_ui.text_no_resize(
				"You've gained a barrel!",
				"Talk to the vendor to change your loadout and buy new barrels."
			)
			show_panel(tutorial_ui)
			GameManager.barrel_tutorial_shown = true
	
	if GameManager.all_bosses_defeated:
		if not GameManager.victory_ui_shown:
			show_panel(game_win_ui)
			GameManager.victory_ui_shown = true


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		ui_accept.emit()


func show_panel(panel: Control) -> void:
	panel.visible = true
	var tween = get_tree().create_tween()
	tween.tween_property(panel, "modulate", Color(Color.WHITE, 1.0), 1.0)
	await tween.finished
	await ui_accept
	tween = get_tree().create_tween()
	tween.tween_property(panel, "modulate", Color(Color.WHITE, 0.0), 1.0)


func _on_level_select(level_path: String) -> void:
	ResourceLoader.load_threaded_request(level_path)
	elevator_doors.close()
	await elevator_doors.anim_player.animation_finished
	# Wait until the level has been loaded on another thread
	while ResourceLoader.load_threaded_get_status(level_path) != ResourceLoader.THREAD_LOAD_LOADED:
		pass
	# Get the player's position relative to the elevator doors
	GameManager.cached_player_pos_relative_to_elevator_doors = elevator_doors.global_position - GameManager.player.global_position
	GameManager.cached_player_rotation = GameManager.player.rotation
	GameManager.cached_camera_rotation = GameManager.player.player_camera.rotation
	var loaded_scene = ResourceLoader.load_threaded_get(level_path)
	# HACK - do this properly with dynamic loading of scenes
  
	if is_inside_tree():
		# TODO - fade this out via tween
		lobby_music_player.stop()
		var new_bgm = loaded_scene.get_state().get_node_property_value(0, 1)
		if new_bgm:
			SoundManager.play_music(new_bgm, 0.25, "BGM")
		get_tree().change_scene_to_packed(loaded_scene)


func _on_door_transition_area_body_entered(body: Node3D) -> void:
	if body is Player:
		elevator_doors.open()


func _on_door_transition_area_body_exited(body: Node3D) -> void:
	if body is Player:
		elevator_doors.close()
