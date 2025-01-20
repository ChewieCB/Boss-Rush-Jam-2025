extends BossCore
class_name BossSurveillance

@export var elevation_speed_deg: float = 25.0
@export var rotation_speed_deg: float = 25.0

@onready var elevation_speed: float = deg_to_rad(elevation_speed_deg)
@onready var rotation_speed: float = deg_to_rad(rotation_speed_deg)

@onready var body: Node3D = $Body
@onready var head: Node3D = $Body/Head
@onready var eye_mesh: MeshInstance3D = $Body/MeshInstance3D
@onready var aim_ray: RayCast3D = $Body/Head/RayCast3D
@onready var anim_player: AnimationPlayer = $AnimationPlayer


# Turrets
var turret_spawns: Array:
	set(value):
		turret_spawns = value
		valid_spawns = turret_spawns.duplicate()
var valid_spawns: Array
var turret_look_target: Node3D
@export var turrets_to_spawn: int = 2
var spawned_turrets_count: int = 0

# Beam
@onready var laser_mesh: MeshInstance3D = $Body/Head/RayCast3D/LaserMesh
@onready var laser_particles: GPUParticles3D = $Body/Head/RayCast3D/LaserMesh/LaserEndParticles


func _ready() -> void:
	GRAVITY = 0
	head.rotate_x(PI)


func _physics_process(delta: float) -> void:
	pass


func activate() -> void:
	super()
	anim_player.play("intro_look_at_player")
	await anim_player.animation_finished
	state_chart.send_event("start_phase_1")


func rotate_and_elevate(target_pos: Vector3, delta: float) -> void:
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


#####

func _on_health_hit_state_entered() -> void:
	eye_mesh.mesh.surface_get_material(0).albedo_color = Color.RED
	sprite.modulate = Color.RED
	await get_tree().create_timer(0.05).timeout
	state_chart.send_event("end_damage")

func _on_health_hit_state_exited() -> void:
	eye_mesh.mesh.surface_get_material(0).albedo_color = Color.WHITE


#####

func _on_phase_1_state_entered() -> void:
	#state_chart.send_event("start_spawn_turrets_attack")
	state_chart.send_event("start_laser_attack")

func _on_phase_1_state_physics_processing(delta: float) -> void:
	pass


func _on_turret_destroyed(turret: PitTurret) -> void:
	var turret_spawn = turret.get_parent()
	valid_spawns.push_back(turret_spawn)


func _on_spawn_turrets_targeting_state_entered() -> void:
	debug_state_label.text = "Spawn Turrets | Targeting"
	await get_tree().create_timer(attack_recovery_time).timeout
	state_chart.send_event("spawn_turrets")

func _on_spawn_turrets_targeting_state_physics_processing(delta: float) -> void:
	rotate_and_elevate(target.global_position, delta)


func _on_spawn_turrets_spawning_state_entered() -> void:
	debug_state_label.text = "Spawn Turrets | Spawning"
	
	for i in turrets_to_spawn:
		if spawned_turrets_count >= turrets_to_spawn:
			break
		var idx: int = randi_range(0, valid_spawns.size() - 1)
		turret_look_target = valid_spawns.pop_at(idx)
		var tween = get_tree().create_tween()
		tween.tween_method(
			rotate_and_elevate.bind(get_physics_process_delta_time()),
			target.global_position, 
			turret_look_target.global_position,
			0.6, 
		)
		await tween.finished
		var turret = turret_look_target.spawn_turret(target)
		turret.health_component.died.connect(_on_turret_destroyed)
		spawned_turrets_count += 1
	turret_look_target = null
	state_chart.send_event("stop_spawning")


func _on_spawn_turrets_recover_state_entered() -> void:
	debug_state_label.text = "Spawn Turrets | Recovering"
	valid_spawns = turret_spawns.duplicate()
	await get_tree().create_timer(attack_recovery_time).timeout
	select_attack()
	state_chart.send_event("end_recovery")


######


func _on_laser_beam_startup_state_entered() -> void:
	# Look down to the center
	var tween = get_tree().create_tween()
	var look_position: Vector3 = self.global_position
	look_position.y = 0
	tween.tween_method(
			rotate_and_elevate.bind(get_physics_process_delta_time()),
			target.global_position, 
			look_position,
			0.4, 
		)
	await tween.finished
	
	# Start up the laser
	var cast_point: Vector3
	aim_ray.force_raycast_update()
	if aim_ray.is_colliding():
		cast_point = aim_ray.get_collision_point()
		var dist_to_cast: float = self.global_position.distance_to(cast_point)
		tween = get_tree().create_tween()
		tween.tween_property(laser_mesh.mesh, "height", dist_to_cast, 0.4)
		tween.parallel().tween_property(laser_mesh, "position:z", dist_to_cast / 2, 0.4)
		
		await tween.finished
	
		laser_particles.global_position = cast_point
		laser_particles.emitting = true
		state_chart.send_event("start_beam")

func _on_laser_beam_startup_state_physics_processing(delta: float) -> void:
	pass


func _on_laser_beam_targeting_state_entered() -> void:
	debug_state_label.text = "Laser Beam | Targeting"
	
	elevation_speed = deg_to_rad(elevation_speed_deg * 0.45)
	rotation_speed = deg_to_rad(rotation_speed_deg * 0.45)

func _on_laser_beam_targeting_state_physics_processing(delta: float) -> void:
	rotate_and_elevate(target.global_position, delta)
	var cast_point: Vector3
	aim_ray.force_raycast_update()
	if aim_ray.is_colliding():
		cast_point = aim_ray.get_collision_point()
		var dist_to_cast: float = self.global_position.distance_to(cast_point)
		laser_mesh.mesh.height = dist_to_cast 
		laser_mesh.position.z = dist_to_cast / 2
		laser_particles.global_position = cast_point


	# TODO - find the player's position and do some sweeping arcs towards them
