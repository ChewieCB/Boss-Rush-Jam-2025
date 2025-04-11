extends HealthBar

@export var boss_name: String = ""

@onready var name_label: Label = $VBoxContainer/MarginContainer/HBoxContainer/MarginContainer2/Label


func _ready() -> void:
	super ()
	name_label.text = boss_name
	await get_tree().process_frame
	await get_tree().process_frame
	GameManager.setting_ui.setting_changed.connect(check_after_setting_changed)
	check_after_setting_changed()

func check_after_setting_changed():
	visible = not GameManager.hide_ui
