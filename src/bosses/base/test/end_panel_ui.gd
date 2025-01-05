extends Control


@onready var label = $PanelContainer/RichTextLabel


func win() -> void:
	label.text = "[center]%s[/center]" % ["Stank\nDefeated"]


func lose() -> void:
	label.text = "[center]%s[/center]" % ["Felled by\nthe beast"]
