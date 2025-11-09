extends Area3D
class_name BlockingDetectionArea

signal raycast_hit(proj: BaseProjectile, pos: Vector3)


func _raycast_hit(proj: BaseProjectile, pos: Vector3) -> void:
	raycast_hit.emit(proj, pos)
