extends BaseTrigger
class_name DPSTrigger

@export var connected_object: Node3D
@onready var label: Label3D = $Label3D
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var health_component: HealthComponent = $HealthComponent

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
	health_component.health_diff.connect(_on_health_diff)
	current_dps_count = 0


func tween_label_text(value: float):
	label.text = str(value)


func _on_health_diff(diff: float) -> void:
	current_dps_count += abs(diff)


func activate() -> void:
	label.modulate = Color.GREEN
	dps_window_timer.stop()
	health_component.is_invincible = true
	
	if connected_object:
		connected_object.activate()


func _on_dps_window_timer_timeout() -> void:
	current_dps_count = 0
