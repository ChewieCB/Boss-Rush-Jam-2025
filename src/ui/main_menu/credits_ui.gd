extends Control


@export var scroll_speed: int = 50

@onready var scroll_container: ScrollContainer = $TabContainer/Control/ScrollContainer

# func _process(delta):
# 	if visible:
# 		var move_y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
# 		scroll_container.scroll_vertical += move_y * scroll_speed * delta

func _unhandled_input(event):
	if visible:
		if event.is_action_pressed("ui_down"):
			scroll_container.scroll_vertical += scroll_speed
		elif event.is_action_pressed("ui_up"):
			scroll_container.scroll_vertical -= scroll_speed