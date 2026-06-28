extends Node

## Spread angle is in degree.
func get_spread_direction(center_direction: Vector3, spread_angle: float, horizontal_bias: float = 0.5) -> Vector3:
	# Clamp bias: 0 = vertical spread, 1 = horizontal spread, 0.5 = normal cone
	horizontal_bias = clamp(horizontal_bias, 0.0, 1.0)

	# Split spread between horizontal (yaw) and vertical (pitch)
	var horizontal_spread = spread_angle * horizontal_bias
	var vertical_spread = spread_angle * (1.0 - horizontal_bias)

	# Random angles for yaw/pitch
	var yaw = deg_to_rad(randf_range(-horizontal_spread, horizontal_spread))
	var pitch = deg_to_rad(randf_range(-vertical_spread, vertical_spread))

	# Get orthogonal basis around center_direction
	var basis = Basis()
	basis.z = center_direction.normalized()
	basis.x = basis.z.cross(Vector3.UP).normalized()
	if basis.x.length() == 0:
		basis.x = Vector3.RIGHT
	basis.y = basis.x.cross(basis.z).normalized()

	# Apply rotations in local space
	var rotated = center_direction
	rotated = rotated.rotated(basis.y, yaw) # horizontal
	rotated = rotated.rotated(basis.x, pitch) # vertical

	return rotated.normalized()


func get_player_aiming_position() -> Vector3:
	if not GameManager.player:
		return Vector3.ZERO

	var laser_guide_ray: RayCast3D = GameManager.player.laser_guide_ray
	if laser_guide_ray.is_colliding():
		var hit_position: Vector3 = laser_guide_ray.get_collision_point()
		return hit_position
	return laser_guide_ray.to_global(laser_guide_ray.target_position)

func angle_between_vectors(vec1: Vector3, vec2: Vector3) -> float:
	# Normalize the vectors
	var vec1_normalized = vec1.normalized()
	var vec2_normalized = vec2.normalized()
	# Calculate the dot product
	var dot_product = vec1_normalized.dot(vec2_normalized)
	# Clamp the dot product to avoid floating-point errors (to keep it between -1 and 1)
	dot_product = clamp(dot_product, -1.0, 1.0)
	# Calculate the angle in radians
	var angle_radians = acos(dot_product)
	# Convert the angle to degrees
	return rad_to_deg(angle_radians)
