extends Control


@onready var rect: ColorRect = $ColorRect
@export var lower_blur: float = 0.015
@export var upper_blur: float = 0.04


func start_drunk() -> void:
	rect.visible = true
	var drunk_tween: Tween = get_tree().create_tween()
	drunk_tween.set_loops()
	drunk_tween.chain().tween_method(
		_set_blur_amount, lower_blur, upper_blur, 1.2
	).set_trans(Tween.TRANS_CIRC)#.set_ease(Tween.EASE_IN)
	drunk_tween.chain().tween_method(
		_set_blur_amount, upper_blur, lower_blur, 1.2
	).set_trans(Tween.TRANS_CIRC)#.set_ease(Tween.EASE_IN)


func end_drunk() -> void:
	rect.visible = false


func _set_blur_amount(amount: float) -> void:
	rect.material.set("shader_parameter/blur_power", amount)
