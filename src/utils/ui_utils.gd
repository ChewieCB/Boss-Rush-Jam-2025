extends Node


func anim_ui_elem_scale(elem: Control, amount: float = 1.1, speed_scale: float = 1.0) -> void:
	elem.pivot_offset = elem.size / 2
	var shake_tween: Tween = get_tree().create_tween()
	shake_tween.set_parallel(false)
	shake_tween.tween_property(elem, "scale", Vector2(amount, amount), 0.05 * speed_scale)
	shake_tween.tween_property(elem, "scale", Vector2.ONE, 0.08 * speed_scale)
