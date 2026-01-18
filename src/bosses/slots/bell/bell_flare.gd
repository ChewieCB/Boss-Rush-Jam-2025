extends MeshInstance3D

@export var travel_duration: float = 1
@export var persist_duration: float = 3

@onready var timer: Timer = $Timer

func init(start_pos: Vector3, end_pos: Vector3, peak_height: float) -> void:
	timer.start(travel_duration + persist_duration)
	global_position = start_pos
	var peak = start_pos + Vector3(0, peak_height, 0)
	var tween = create_tween()
	tween.tween_method(
		func(t):
			global_position = start_pos.lerp(peak, t).lerp(
				peak.lerp(end_pos, t), t
			),
		0.0,
		1.0,
		travel_duration
	)


func _on_timer_timeout() -> void:
	queue_free()
