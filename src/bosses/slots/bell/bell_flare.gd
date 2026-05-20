extends MeshInstance3D

signal finished

@export var travel_duration: float = 1
@export var persist_duration: float = 3

@onready var timer: Timer = $Timer


func init(start_pos: Vector3, end_pos: Vector3, peak_height: float) -> void:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		end_pos + Vector3(0, 2, 0),
		end_pos - Vector3(0, 2, 0),
		int(pow(2, 1 - 1))
	)
	var result = space_state.intersect_ray(query)
	if result:
		end_pos.y = result.position.y
	
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
	finished.emit()


func activate() -> void:
	self.visible = true
	self.process_mode = Node.PROCESS_MODE_INHERIT


func deactivate() -> void:
	self.visible = false
	self.process_mode = Node.PROCESS_MODE_DISABLED
