extends Node

## Spread angle is in degree.
func get_spread_direction(center_direction: Vector3, spread_angle: float) -> Vector3:
	# Convert spread angle to radians
	var max_radians = deg_to_rad(spread_angle)

	# Generate random rotation within the spread cone
	var random_yaw = randf_range(-max_radians, max_radians)
	var random_pitch = randf_range(-max_radians, max_radians)

	# Create a rotation basis
	var spread_rotation = Basis(Vector3.UP, random_yaw) * Basis(Vector3.RIGHT, random_pitch)

	# Apply the rotation to the center direction
	return (spread_rotation * center_direction).normalized()