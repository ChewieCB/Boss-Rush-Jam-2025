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

var previous_phase: String

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
@onready var laser_area: Area3D = $Body/Head/RayCast3D/Area3D
@onready var laser_collider: CollisionShape3D = $Body/Head/RayCast3D/Area3D/LaserCollider
@onready var laser_mesh: MeshInstance3D = $Body/Head/RayCast3D/Area3D/LaserMesh
@onready var laser_particles: GPUParticles3D = $Body/Head/RayCast3D/Area3D/LaserMesh/LaserEndParticles
var beam_target: Vector3
@export var beam_sweeps_per_attack: int = 4
var beam_sweep_count: int = 0
@export var beam_sweep_delay: float = 1.2

# Barrier Cage
@export var barrier_cage_radius: float = 24.0
@export var barrier_cage_reflect_force: float = 12.0
@export var barrier_cage_time: float = 12.0
@export var barrier_cage_material: Material
@onready var barrier_cage_area: Area3D = $BarrierCageArea
@onready var barrier_cage_collider: CollisionShape3D = $BarrierCageArea/CollisionShape3D
@onready var barrier_cage_mesh: MeshInstance3D = $BarrierCageArea/MeshInstance3D


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


func select_attack_phase_1() -> void:
	var dist_to_target = self.global_position.distance_to(target.global_position)
	var possible_phases = [
		#"start_spawn_turrets_attack",
		"start_laser_attack",
		"start_barrier_cage_attack",
	]
	
	if previous_phase:
		possible_phases.erase(previous_phase)
	
	var new_phase: String = possible_phases[randi_range(0, possible_phases.size() - 1)]
	previous_phase = new_phase
	state_chart.send_event(new_phase)


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
	select_attack()

func _on_phase_1_state_physics_processing(delta: float) -> void:
	pass


func _on_turret_destroyed(turret: PitTurret) -> void:
	var turret_spawn = turret.get_parent()
	valid_spawns.push_back(turret_spawn)
	spawned_turrets_count -= 1


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
		turret.destroyed.connect(_on_turret_destroyed)
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
		tween.parallel().tween_property(laser_mesh, "position:z", dist_to_cast / 2 - 0.4, 0.4)
		tween.parallel().tween_property(laser_collider.shape, "height", dist_to_cast, 0.4)
		tween.parallel().tween_property(laser_collider, "position:z", dist_to_cast / 2 - 0.4, 0.4)
		
		await tween.finished
	
		laser_particles.global_position = cast_point
		laser_particles.emitting = true
		state_chart.send_event("start_beam")


# Add a debug sphere at global location.
func draw_debug_sphere(location, size):
	# Will usually work, but you might need to adjust this.
	var scene_root = get_tree().root.get_children()[0]
	# Create sphere with low detail of size.
	var sphere = SphereMesh.new()
	sphere.radial_segments = 4
	sphere.rings = 4
	sphere.radius = size
	sphere.height = size * 2
	# Bright red material (unshaded).
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1, 0, 0)
	material.flags_unshaded = true
	sphere.surface_set_material(0, material)

	# Add to meshinstance in the right place.
	var node = MeshInstance3D.new()
	node.mesh = sphere
	node.global_transform.origin = location
	scene_root.add_child(node)
	
	return node


func _on_laser_beam_startup_state_physics_processing(delta: float) -> void:
	pass


func _on_laser_beam_targeting_state_entered() -> void:
	debug_state_label.text = "Laser Beam | Targeting"
	
	elevation_speed = deg_to_rad(elevation_speed_deg * 0.65)
	rotation_speed = deg_to_rad(rotation_speed_deg * 0.65)
	
	await get_tree().create_timer(beam_sweep_delay).timeout
	
	if beam_sweep_count < beam_sweeps_per_attack:
		beam_target = target.global_position
		beam_sweep_count += 1
		state_chart.send_event("sweep_beam")
	else:
		beam_sweep_count = 0
		state_chart.send_event("end_beam")

func _on_laser_beam_targeting_state_physics_processing(delta: float) -> void:
	rotate_and_elevate(target.global_position, delta)
	var cast_point: Vector3
	aim_ray.force_raycast_update()
	if aim_ray.is_colliding():
		cast_point = aim_ray.get_collision_point()
		var dist_to_cast: float = aim_ray.global_position.distance_to(cast_point)
		laser_mesh.mesh.height = dist_to_cast 
		laser_mesh.position.z = dist_to_cast / 2
		laser_collider.shape.height = dist_to_cast
		laser_collider.position.z = dist_to_cast / 2
		laser_particles.global_position = cast_point


func _on_laser_beam_sweep_beam_state_entered() -> void:
	debug_state_label.text = "Laser Beam | Sweep"
	# TODO - add telegraphing to the sweep attack
	var tween = get_tree().create_tween()
	tween.tween_property(laser_mesh.mesh, "top_radius", 1.5, 0.8)
	tween.parallel().tween_property(laser_mesh.mesh, "bottom_radius", 1.5, 0.8)
	tween.parallel().tween_property(laser_particles, "scale", Vector3(3, 3, 3), 0.8)
	tween.parallel().tween_property(laser_collider.shape, "top_radius", 1.5, 0.8)
	tween.parallel().tween_property(laser_collider.shape, "bottom_radius", 1.5, 0.8)
	
	# TODO - glow the laser to indicate sweep start
	await get_tree().create_timer(telegraph_time).timeout
	elevation_speed = deg_to_rad(elevation_speed_deg * 1.0)
	rotation_speed = deg_to_rad(rotation_speed_deg * 1.0)
	
	# Sweep towards the player's position
	beam_target = target.global_position


func _on_laser_beam_sweep_beam_state_physics_processing(delta: float) -> void:
	rotate_and_elevate(beam_target, delta)
	
	var cast_point: Vector3
	aim_ray.force_raycast_update()
	if aim_ray.is_colliding():
		cast_point = aim_ray.get_collision_point()
		var dist_to_cast: float = aim_ray.global_position.distance_to(cast_point)
		laser_mesh.mesh.height = dist_to_cast 
		laser_mesh.position.z = dist_to_cast / 2
		laser_particles.global_position = cast_point
		
		var aim_dir = aim_ray.global_basis.z.normalized()
		var target_dir = (beam_target - aim_ray.global_position).normalized()
		if aim_dir.dot(target_dir) > 0.999:
			state_chart.send_event("end_sweep")


func _on_laser_beam_recover_state_entered() -> void:
	debug_state_label.text = "Laser Beam | Recovering"
	
	var tween = get_tree().create_tween()
	tween.tween_property(laser_mesh.mesh, "height", 0.1, 0.4)
	tween.parallel().tween_property(laser_mesh, "position:z", 0.4, 0.4)
	tween.parallel().tween_property(laser_collider.shape, "height", 0.1, 0.4)
	tween.parallel().tween_property(laser_collider, "position:z", 0.4, 0.4)
	tween.parallel().tween_property(laser_mesh.mesh, "top_radius", 0.3, 0.8)
	tween.parallel().tween_property(laser_mesh.mesh, "bottom_radius", 0.3, 0.8)
	tween.parallel().tween_property(laser_particles, "scale", Vector3(1, 1, 1), 0.8)
	tween.parallel().tween_property(laser_collider.shape, "top_radius", 0.3, 0.8)
	tween.parallel().tween_property(laser_collider.shape, "bottom_radius", 0.3, 0.8)
	
	await tween.finished
	laser_particles.emitting = false
	await get_tree().create_timer(attack_recovery_time).timeout
	
	select_attack()
	state_chart.send_event("end_recovery")


func _on_laser_hurtbox_body_entered(body: Node3D) -> void:
	if body == target:
		target.health_component.damage(10)
		laser_area.monitoring = false
		await get_tree().create_timer(0.4).timeout
		laser_area.monitoring = true

##### Barrier Cage

func _on_barrier_cage_state_physics_processing(delta: float) -> void:
	rotate_and_elevate(target.global_position, delta)
	var target_floor_pos = target.global_position
	target_floor_pos.y = 0
	var current_cage_radius: float = barrier_cage_collider.shape.radius
	if target_floor_pos.distance_to(Vector3.ZERO) > current_cage_radius:
		var reflect_dir = target.global_position.direction_to(Vector3.ZERO)
		var barrer_point: Vector3 = -reflect_dir * current_cage_radius
		target.global_position.x = barrer_point.x
		target.global_position.z = barrer_point.z


func _on_barrier_cage_targeting_state_entered() -> void:
	debug_state_label.text = "Barrier Cage | Targeting"
	
	elevation_speed = deg_to_rad(elevation_speed_deg)
	rotation_speed = deg_to_rad(rotation_speed_deg)
	
	await get_tree().create_timer(0.3).timeout
	state_chart.send_event("spawn_cage")


func _on_barrier_cage_spawn_cage_state_entered() -> void:
	debug_state_label.text = "Barrier Cage | Spawning"
	barrier_cage_area.visible = true
	barrier_cage_area.monitoring = true
	
	var cage_tween = get_tree().create_tween()
	cage_tween.tween_property(barrier_cage_mesh.mesh, "top_radius", barrier_cage_radius, 0.8)
	cage_tween.parallel().tween_property(barrier_cage_mesh.mesh, "bottom_radius", barrier_cage_radius, 0.8)
	cage_tween.parallel().tween_property(barrier_cage_collider.shape, "radius", barrier_cage_radius, 0.8)
	await cage_tween.finished
	
	await get_tree().create_timer(barrier_cage_time).timeout
	state_chart.send_event("end_cage")


func _on_barrier_cage_spawn_cage_state_exited() -> void:
	barrier_cage_area.monitoring = false
	
	var cage_tween = get_tree().create_tween()
	cage_tween.tween_property(barrier_cage_mesh.mesh, "top_radius", 42.0, 0.8)
	cage_tween.parallel().tween_property(barrier_cage_mesh.mesh, "bottom_radius", 42.0, 0.8)
	cage_tween.parallel().tween_property(barrier_cage_collider.shape, "radius", 42.0, 0.8)
	await cage_tween.finished
	
	barrier_cage_area.visible = false


func _on_barrier_cage_recover_state_entered() -> void:
	debug_state_label.text = "Barrier Cage | Recovering"
	await get_tree().create_timer(attack_recovery_time).timeout
	select_attack()
	state_chart.send_event("end_recovery")


#func _on_laser_beam_state_physics_processing(delta: float) -> void:
	#draw_debug_sphere(aim_ray.get_collision_point(), 0.5)
