extends HealthBar

@export var boss_name: String = ""

@onready var name_label: Label = $VBoxContainer/MarginContainer/HBoxContainer/MarginContainer2/Label


func _ready() -> void:
	name_label.text = boss_name
	super()
