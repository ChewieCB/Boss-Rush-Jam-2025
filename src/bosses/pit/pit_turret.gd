extends StaticBody3D
class_name PitTurret


@onready var body: Node3D = $Body
@onready var head: Node3D = $Body/Head
@onready var dome_mesh: MeshInstance3D = $Body/Dome
@onready var dome_collider: CollisionShape3D = $DomeCollider

@onready var health_component: HealthComponent = $HealthComponent

@export var elevation_speed_deg: float = 50.0
@export var rotation_speed_deg: float = 50.0

@export var target: Node3D
@export var aim_rays: Array[RayCast3D]

@onready var elevation_speed: float = deg_to_rad(elevation_speed_deg)
@onready var rotation_speed: float = deg_to_rad(rotation_speed_deg)


func _physics_process(delta: float) -> void:
	#if target:
	rotate_and_elevate(delta, target.global_position)
	
	for ray in aim_rays:
		var aim_collision = ray.get_collider()
		if aim_collision == target:
			dome_mesh.mesh.surface_get_material(0).albedo_color = Color.RED
			break
		elif aim_collision != null:
			dome_mesh.mesh.surface_get_material(0).albedo_color = Color.YELLOW
			break
		else:
			dome_mesh.mesh.surface_get_material(0).albedo_color = Color.WHITE


func rotate_and_elevate(delta: float, target_pos: Vector3) -> void:
	# Project the target onto the XZ plane of the turret
	# but first adjust by the global position because 
	# the global basis is purely orientation, not position.
	var rotation_targ: Vector3 = get_projected(
		target_pos - body.global_position, 
		body.global_basis.y
	)
	# We also need to account for changes in position,
	# so add the global position adjustment back in.
	rotation_targ = rotation_targ + body.global_position
	
	# Get the angle from the body's facing direction (z) to the projected point.
	# Since the point is projected onto the plane, this should be the angle
	# the body should rotate to face along only one axis.
	var y_angle: float = get_angle_to_target(
		body.global_position, 
		rotation_targ,
		body.global_basis.z
	)
	# Calculate sign to rotate left or right
	var rotation_sign: float = sign(body.to_local(target_pos).x)
	# Calculate step size and direction. Use min to avoid over-rotating.
	var final_y: float = rotation_sign * min(rotation_speed * delta, y_angle)
	body.rotate_y(final_y)
	
	# Elevation
	var elevation_targ: Vector3 = get_projected(
		target_pos - head.global_position, 
		head.global_basis.x
	)
	elevation_targ = elevation_targ + head.global_position
	
	var x_angle: float = get_angle_to_target(
		head.global_position, 
		elevation_targ,
		head.global_basis.z
	)
	
	var elevation_sign = -sign(head.to_local(target_pos).y)
	var final_x: float = elevation_sign * min(elevation_speed * delta, x_angle)
	head.rotate_x(final_x)


func get_projected(pos: Vector3, normal: Vector3) -> Vector3:
	# Project position "pos" onto the plane with the given normal vector,
	# "projected" is the vector indicating how far above/below
	# the target is from the plane of rotation.
	normal = normal.normalized()
	var projection: Vector3 = (pos.dot(normal) / normal.dot(normal)) * normal
	# By subtracting projection from position, we get the projected point.
	return pos - projection


func get_angle_to_target(seeker_pos: Vector3, target_pos: Vector3, facing_dir: Vector3) -> float:
	var dir_to = seeker_pos.direction_to(target_pos)
	facing_dir = facing_dir.normalized()
	dir_to = dir_to.normalized()
	return acos(facing_dir.dot(dir_to))
