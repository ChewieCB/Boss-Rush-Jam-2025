extends Control

@export var TEMP_bgm: AudioStream

@onready var version_label: RichTextLabel = $Panel/MarginContainer/VBoxContainer/VBoxContainer/BuildNumber


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	SoundManager.play_music(TEMP_bgm)
	var project_version = ProjectSettings.get_setting("application/config/version")
	version_label.text = "[center]%s[/center]" % [project_version]


func _on_button_1_pressed() -> void:
	get_tree().change_scene_to_file("res://src/player/test_scenes/Test_PlayerMovement.tscn")


func _on_button_2_pressed() -> void:
	get_tree().change_scene_to_file("res://src/maps/Test_FuncGodotMap.tscn")


func _on_button_3_pressed() -> void:
	get_tree().change_scene_to_file("res://src/bosses/base/test/Test_BossCore.tscn")
