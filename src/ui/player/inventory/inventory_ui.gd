extends Control
class_name InventoryUI

func _ready() -> void:
	visible = false

func toggle():
	# TODO: Pause/Slow game while open inventory
	if visible:
		close()
	else:
		open()
		
func open():
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	Engine.time_scale = 0.2

func close():
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	Engine.time_scale = 1
