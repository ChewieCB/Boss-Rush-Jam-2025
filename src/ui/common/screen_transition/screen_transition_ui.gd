extends CanvasLayer

signal transition_finished

@onready var ui: ColorRect = $UI/ColorRect
@onready var loading_label: Label = $UI/ColorRect/Label


func fill_screen() -> void:
	ui.material.set("shader_parameter/transition_angle", 180.0)
	ui.material.set("shader_param/height", 0.0)


func clear_screen() -> void:
	ui.material.set("shader_parameter/transition_angle", 0.0)
	ui.material.set("shader_param/height", 1.0)


func transition_in(duration: float = 0.7) -> void:
	loading_label.visible = false
	clear_screen()
	tween_transition(1.0, -1.0, duration)


func transition_out(duration: float = 0.7) -> void:
	fill_screen()
	await tween_transition(0.0, 2.0, duration)
	loading_label.visible = true


func tween_transition(start: float, finish: float, duration: float = 0.7) -> void:
	var transition_tween := get_tree().create_tween()
	transition_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	transition_tween.tween_method(
		_set_transition_height, start, finish, duration
	)
	await transition_tween.finished
	transition_finished.emit()


func _set_transition_height(height: float) -> void:
	ui.material.set("shader_param/height", height)
