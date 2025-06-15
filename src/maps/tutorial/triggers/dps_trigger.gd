extends BaseTrigger
class_name DPSTrigger

@export var target_dps_count: float = 60.0
@export var dps_window_time: float = 1.1
@onready var dps_window_timer: Timer = $DPSWindowTimer
var current_dps_count: float = 0.0:
	set(value):
		var old_value: int = int(current_dps_count)
		current_dps_count = value
		var tween = get_tree().create_tween()
		tween.tween_method(tween_label_text, old_value, current_dps_count, 0.2) 
		if current_dps_count >= target_dps_count:
			activate()
			return
		if dps_window_timer.is_stopped():
			dps_window_timer.start(dps_window_time)


func _ready() -> void:
	super()
	current_dps_count = 0


func _on_health_diff(diff: float) -> void:
	current_dps_count += abs(diff)


func activate() -> void:
	dps_window_timer.stop()
	super()


func _on_dps_window_timer_timeout() -> void:
	current_dps_count = 0
