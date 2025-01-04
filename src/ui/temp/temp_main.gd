extends Control

@onready var version_label: RichTextLabel = $Panel/MarginContainer/VBoxContainer/VBoxContainer/BuildNumber


func _ready() -> void:
	var project_version = ProjectSettings.get_setting("application/config/version")
	version_label.text = "[center]%s[/center]" % [project_version]


func _on_button_1_pressed() -> void:
	get_tree().change_scene_to_file("res://src/player/test_scenes/Test_PlayerMovement.tscn")
