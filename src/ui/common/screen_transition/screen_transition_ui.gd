extends Control

signal transition_finished

@onready var ui: ColorRect = $ColorRect


func fill_screen() -> void:
	ui.material.set("shader_param/height", 1.0)


func clear_screen() -> void:
	ui.material.set("shader_param/height", -1.0)


func transition_in(duration: float) -> void:
	ui.material.set("shader_parameter/transparent_dots", true)
	ui.material.set("shader_parameter/transition_angle", 0.0)
	tween_transition(1.0, -1.0, duration)


func transition_out(duration: float) -> void:
	ui.material.set("shader_parameter/transparent_dots", false)
	ui.material.set("shader_parameter/transition_angle", 180.0)
	tween_transition(-1.0, 2.0, duration)


func tween_transition(start: float, finish: float, duration: float) -> void:
	var transition_tween := get_tree().create_tween()
	transition_tween.tween_method(
		_set_transition_height, start, finish, duration
	)
	await transition_tween.finished
	transition_finished.emit()


func _set_transition_height(height: float) -> void:
	ui.material.set("shader_param/height", height)
