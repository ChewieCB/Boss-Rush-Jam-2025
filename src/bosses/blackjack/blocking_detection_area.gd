extends Area3D
class_name BlockingDetectionArea

signal raycast_hit(proj: BaseProjectile, pos: Vector3)

var disabled: bool = false


func _raycast_hit(proj: BaseProjectile, pos: Vector3) -> Vector3:
	# Return the mid-point between the boss and the collision
	var to_boss: Vector3 = self.global_position - pos
	var new_col_pos: Vector3 = pos + to_boss * 0.5
	raycast_hit.emit(proj, new_col_pos)
	return new_col_pos
	
