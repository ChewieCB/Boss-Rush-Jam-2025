extends HBoxContainer
class_name InteractUI

@onready var interact_label: Label = $Label

func show_custom_text(content: String) -> void:
	interact_label.text = content
	visible = true

func show_default_text() -> void:
	interact_label.text = 'Interact'
	visible = true
