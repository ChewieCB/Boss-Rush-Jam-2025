extends Control


@export var bgm: AudioStream
var bgm_player: AudioStreamPlayer
@export var button_sfx: Array[AudioStream]
@export var start_game_sfx: AudioStream

@export var lobby_scene: PackedScene

@onready var buttons: Array[Button] = [
	$TitleColumn/VBoxContainer/OptionsButton,
	$TitleColumn/VBoxContainer/CreditButton,
	$TitleColumn/VBoxContainer/QuitButton,
]

func _ready() -> void:
	bgm_player = SoundManager.play_music(bgm, 0.2, "BGM")
	for button in buttons:
		button.pressed.connect(_play_button_sfx)


func _play_button_sfx() -> void:
	SoundManager.play_ui_sound(button_sfx.pick_random(), "UI")


func _on_start_button_pressed() -> void:
	var current_beat_time = bgm.get_bpm() * bgm_player.get_playback_position() / 120.0
	var next_beat_time = ceilf(current_beat_time)
	await get_tree().create_timer(next_beat_time - current_beat_time).timeout
	bgm_player.stop()
	SoundManager.play_ui_sound(start_game_sfx, "UI")
	get_tree().change_scene_to_packed(lobby_scene)
	


func _on_quit_button_pressed() -> void:
	get_tree().quit()
