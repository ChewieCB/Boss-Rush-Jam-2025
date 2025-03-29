extends CanvasLayer

signal transition_finished

@onready var ui: ColorRect = $UI/ColorRect


func fill_screen() -> void:
	ui.material.set("shader_parameter/transition_angle", 180.0)
	ui.material.set("shader_param/height", 0.0)


func clear_screen() -> void:
	ui.material.set("shader_parameter/transition_angle", 0.0)
	ui.material.set("shader_param/height", 1.0)


func transition_in(duration: float = 0.7) -> void:
	clear_screen()
	print("======== TRANS IN ========")
	tween_transition(1.0, -1.0, duration)
	print("==========================")


func transition_out(duration: float = 0.7) -> void:
	fill_screen()
	print("======== TRANS OUT ========")
	tween_transition(0.0, 2.0, duration)
	print("============================")


func tween_transition(start: float, finish: float, duration: float = 0.7) -> void:
	print("Start transition: %s -> %s" % [start, finish])
	var transition_tween := get_tree().create_tween()
	transition_tween.tween_method(
		_set_transition_height, start, finish, duration
	)
	await transition_tween.finished
	transition_finished.emit()
	print("End transition")


func _set_transition_height(height: float) -> void:
	ui.material.set("shader_param/height", height)
