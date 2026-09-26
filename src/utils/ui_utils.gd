extends Node


func anim_ui_elem_scale(elem: Control, amount: float = 1.1, speed_scale: float = 1.0) -> Tween:
	elem.pivot_offset = elem.size / 2
	var shake_tween: Tween = get_tree().create_tween()
	shake_tween.set_parallel(false)
	shake_tween.tween_property(elem, "scale", Vector2(amount, amount), 0.05 * speed_scale)
	shake_tween.tween_property(elem, "scale", Vector2.ONE, 0.08 * speed_scale)
	
	return shake_tween


func animate_ui_elem_shake(elem: Control) -> void:
	elem.pivot_offset = elem.size / 2
	var anim_tween: Tween = get_tree().create_tween()
	anim_tween.set_parallel(false)
	anim_tween.tween_property(elem , "scale", Vector2(0.8, 0.8), 0.05)
	anim_tween.tween_property(elem , "scale", Vector2(1.1, 1.1), 0.06).set_ease(Tween.EASE_IN)
	anim_tween.tween_property(elem , "scale", Vector2(1.0, 1.0), 0.08).set_ease(Tween.EASE_OUT)
	
	await anim_tween.finished
	
	return
