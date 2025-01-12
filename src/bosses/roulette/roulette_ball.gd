extends RigidBody3D
class_name RouletteBall


@export var wheel_center: Vector3 = Vector3.ZERO


func _physics_process(_delta: float) -> void:
	var to_sphere = self.global_transform.origin - wheel_center
	var tangent_dir = Vector3.UP.cross(to_sphere).normalized()
	var ball_force = tangent_dir * 1500.0
	var central_force = self.global_position.direction_to(wheel_center) * 5000
	# Close circle = 1500 | 10,000
	# Mid circle = ? | ?
	apply_central_force(ball_force)
	apply_central_force(central_force)
