extends Control
class_name MainMenu

@export var bgm: AudioStream
var bgm_player: AudioStreamPlayer
@export var button_sfx: Array[AudioStream]
@export var start_game_sfx: AudioStream

@export var lobby_scene: PackedScene

@onready var buttons_container: Container = $TitleColumn/VBoxContainer
@onready var buttons = buttons_container.get_children()
@onready var settings_ui = $SettingUI
@onready var credits_ui = $CreditsUI
@onready var story_ui = $StoryUI
@onready var save_ui = $SaveUI
@onready var title_column = $TitleColumn


func _ready() -> void:
	Engine.time_scale = 1
	SoundManager.stop_music(0.1)
	LoadingHandler.current_scene_path = "res://src/maps/lobby/Lobby.tscn"
	bgm_player = SoundManager.play_music(bgm, 0.2, "BGM")
	get_tree().paused = false
	
	ScreenTransition.transition_in()
	await ScreenTransition.transition_finished
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	save_ui.visible = false
	for button in buttons:
		button.pressed.connect(_play_button_sfx)


func _play_button_sfx() -> void:
	SoundManager.play_ui_sound(button_sfx.pick_random(), "UI")


func _on_start_button_pressed() -> void:
	story_ui.visible = false
	credits_ui.visible = false
	settings_ui.visible = false
	save_ui.visible = true
	

func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_options_button_pressed() -> void:
	buttons_container.visible = false
	credits_ui.visible = false
	story_ui.visible = false
	save_ui.visible = false
	settings_ui.visible = true
	title_column.visible = false


func _on_credit_button_pressed() -> void:
	credits_ui.visible = !credits_ui.visible
	story_ui.visible = !story_ui.visible
	save_ui.visible = false


func start_game():
	var current_beat_time = bgm.get_bpm() * bgm_player.get_playback_position() / 120.0
	var next_beat_time = ceilf(current_beat_time)
	await get_tree().create_timer(next_beat_time - current_beat_time).timeout
	bgm_player.stop()
	SoundManager.play_ui_sound(start_game_sfx, "UI")
	LoadingHandler.start_loading("Lobby")


func play_button_hover_sfx():
	SoundManager.play_button_hover_sfx()


func _on_setting_ui_setting_back_button_pressed() -> void:
	buttons_container.visible = true
	settings_ui.visible = false
	story_ui.visible = true
	title_column.visible = true
	SaveManager.save_setting_config()
