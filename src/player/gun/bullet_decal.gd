extends Decal

@export var fade_speed = 2.0

var alpha = 1.0
var start_fade = false


func _process(delta: float) -> void:
	if start_fade:
		alpha -= delta * fade_speed
		alpha = clamp(alpha, 0, 1)
		modulate.a = alpha
	if modulate.a == 0:
		queue_free()

func _on_timer_timeout() -> void:
	start_fade = true
