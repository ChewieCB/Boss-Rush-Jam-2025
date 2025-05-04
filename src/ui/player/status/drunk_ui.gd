extends Control


@onready var rect: ColorRect = $ColorRect
var drunk_tween: Tween
@export var lower_blur: float = 0.015
@export var upper_blur: float = 0.03


func start_drunk() -> void:
	drunk_tween = create_tween()
	drunk_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	drunk_tween.tween_method(
		_set_blur_amount, 0.0, lower_blur, 0.6
	).set_ease(Tween.EASE_IN)
	drunk_tween.parallel().tween_property(
		rect, "color:a", 1.0, 0.6
	).set_ease(Tween.EASE_IN)
	await drunk_tween.finished
	drunk_tween = create_tween()
	drunk_tween.chain().tween_method(
		_set_blur_amount, lower_blur, upper_blur, 0.8
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	drunk_tween.chain().tween_method(
		_set_blur_amount, upper_blur, lower_blur, 0.8
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	drunk_tween.set_loops()


func end_drunk() -> void:
	if drunk_tween:
		drunk_tween.kill()
	drunk_tween = create_tween()
	
	var current_blur = rect.material.get("shader_parameter/blur_power")
	drunk_tween.tween_method(
		_set_blur_amount, current_blur, 0.0, 0.3
	).set_ease(Tween.EASE_OUT)
	drunk_tween.parallel().tween_property(
		rect, "color:a", 0.0, 0.6
	).set_ease(Tween.EASE_OUT)


func _set_blur_amount(amount: float) -> void:
	rect.material.set("shader_parameter/blur_power", amount)
