extends Node

## Spread angle is in degree.
func get_spread_direction(center_direction: Vector3, spread_angle: float) -> Vector3:
	# max_angle_deg is the max deviation from the center vector (like cone spread), in degrees
	var axis = center_direction.normalized()

	# Create a random rotation axis perpendicular to center_direction
	var random_dir = Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	)

	# Ensure it's not parallel
	random_dir = random_dir.cross(axis).normalized()
	if random_dir.length() == 0:
		random_dir = Vector3.UP.cross(axis).normalized()

	# Choose a random angle within the cone
	var angle_rad = deg_to_rad(randf_range(0.0, spread_angle))

	# Rotate the original direction around the random perpendicular axis
	var rotated_dir = center_direction.rotated(random_dir, angle_rad)

	return rotated_dir.normalized()