extends Control

@onready var version_label: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/VBoxContainer/BuildNumber


func _ready() -> void:
	var project_version = ProjectSettings.get_setting("application/config/version")
	version_label.text = "[center]%s[/center]" % [project_version]
