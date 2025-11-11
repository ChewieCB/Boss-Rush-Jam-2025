extends Label3D
class_name HitText

@export var rise_height: float = 2.0
@export var duration: float = 0.6
@export var fade_delay: float = 0.2
@export var scale_pop: float = 1.3
@export var horizontal_jitter: float = 0.5 # how far left/right it can drift

func activate() -> void:
	modulate.a = 1.0
	scale = Vector3.ONE * 0.8

	var tween = create_tween()

	# random slight left/right offset for variety
	var jitter_x = randf_range(-horizontal_jitter, horizontal_jitter)
	var target_pos = position + Vector3(jitter_x, rise_height, 0)

	# pop animation
	tween.tween_property(self, "scale", Vector3.ONE * scale_pop, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)

	# move + fade out
	tween.parallel().tween_property(self, "position", target_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 0.0, duration - fade_delay).set_delay(fade_delay)

	tween.tween_callback(queue_free)
