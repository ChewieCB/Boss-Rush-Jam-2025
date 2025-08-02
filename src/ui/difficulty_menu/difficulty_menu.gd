extends Control

@onready var risk_level_container: Container = $TitleRegion/HBoxContainer


func _ready() -> void:
	set_risk_level(4)

## Max lv 15
func set_risk_level(level: int):
	for i in range(risk_level_container.get_child_count()):
		if i < level:
			risk_level_container.get_child(i).modulate = Color.WHITE
		else:
			risk_level_container.get_child(i).modulate = Color.BLACK
