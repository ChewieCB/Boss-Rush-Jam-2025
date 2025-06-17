extends BossMap

@export var boss_doors: ElevatorDoors
@export var exit_doors: ElevatorDoors


func _ready() -> void:
	super()
	boss_doors.close()


func _on_boss_door_trigger_volume_body_entered(body: Node3D) -> void:
	if body is Player:
		boss_doors.open()


func _on_boss_door_trigger_volume_body_exited(body: Node3D) -> void:
	if body is Player:
		boss_doors.close()


func _on_elevator_door_trigger_volume_body_entered(body: Node3D) -> void:
	if body is Player:
		exit_doors.open()


func _on_elevator_door_trigger_volume_body_exited(body: Node3D) -> void:
	if body is Player:
		exit_doors.close()


func _on_debug_boss_trigger_body_entered(body: Node3D) -> void:
	if body is Player:
		pass
