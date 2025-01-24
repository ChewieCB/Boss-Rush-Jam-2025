extends Node3D
class_name TurretSpawnPoint

@export var turret_scene: PackedScene


func _ready() -> void:
	pass


func spawn_turret(target: Node3D) -> PitTurret:
	var turret = turret_scene.instantiate()
	add_child(turret)
	turret.global_position = self.global_position
	turret.rotation.y = self.rotation.y
	turret.target = target
	return turret
