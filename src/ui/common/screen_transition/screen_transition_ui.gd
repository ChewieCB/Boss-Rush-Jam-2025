extends CanvasLayer

signal transition_midpoint
signal transition_finished

@onready var ui: ColorRect = $UI/ColorRect
@onready var loading_label: Label = $UI/ColorRect/VBoxContainer/LoadingLabel
@onready var loading_detail_label: Label = $UI/ColorRect/VBoxContainer/LoadingDetailLabel
@onready var progress_bar: ProgressBar = $UI/ColorRect/VBoxContainer/ProgressBar


func _ready() -> void:
	transition_in(0.0)


func update_progress_bar(value: float) -> void:
	progress_bar.value = value

func set_loading_detail_text(detail_text: String) -> void:
	loading_detail_label.text = detail_text


func set_loading_visible(value: bool = true) -> void:
	# TODO - add some small animations here for polish
	loading_label.visible = value
	#progress_bar.visible = value
	loading_detail_label.visible = value


func _fill_screen() -> void:
	ui.material.set_shader_parameter("transition_angle", 180.0)
	ui.material.set_shader_parameter("height", 0.0)


func _clear_screen() -> void:
	ui.material.set_shader_parameter("transition_angle", 0.0)
	ui.material.set_shader_parameter("height", 1.0)


func transition_in(duration: float = 0.7) -> void:
	set_loading_visible(false)
	_clear_screen()
	await tween_transition(1.0, -1.0, duration)
	transition_finished.emit()


func transition_out(duration: float = 0.7) -> void:
	_fill_screen()
	await tween_transition(0.0, 2.0, duration)
	set_loading_visible()
	transition_finished.emit()


func tween_transition(start: float, finish: float, duration: float = 0.7) -> void:
	var diff: float = finish - start
	var transition_tween := get_tree().create_tween()
	transition_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	transition_tween.set_parallel(false)
	transition_tween.tween_method(
		_set_transition_height, start, start + diff / 2, duration / 2
	)
	transition_tween.tween_callback(transition_midpoint.emit)
	transition_tween.tween_method(
		_set_transition_height, start + diff / 2, finish, duration / 2
	)
	await transition_tween.finished


func _set_transition_height(height: float) -> void:
	ui.material.set_shader_parameter("height", height)
