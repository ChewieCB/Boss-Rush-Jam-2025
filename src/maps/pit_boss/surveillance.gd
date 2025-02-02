extends BossCore
class_name BossSurveillance

enum Stance {DEFENSIVE, AGGRESSIVE}

@export var elevation_speed_deg: float = 25.0
@export var rotation_speed_deg: float = 25.0

@export_category("Phases")
@export var pit_boss: BossPit 
var phase_stance: Stance = Stance.DEFENSIVE:
	set(value):
		phase_stance = value
		if phase_stance == Stance.AGGRESSIVE:
			state_chart.send_event("aggressive_stance")
		elif phase_stance == Stance.DEFENSIVE:
			state_chart.send_event("defensive_stance")
		phase_debug_label.text = "Phase %s (%s)" % [current_phase, Stance.keys()[phase_stance]]
		select_attack()

@onready var elevation_speed: float = deg_to_rad(elevation_speed_deg)
@onready var rotation_speed: float = deg_to_rad(rotation_speed_deg)

@onready var body: Node3D = $Body
@onready var head: Node3D = $Body/Head
@onready var eye_mesh: MeshInstance3D = $Body/MeshInstance3D
@onready var aim_ray: RayCast3D = $Body/Head/RayCast3D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var phase_debug_label: Label3D = $DebugPhaseLabel

@onready var sfx_player: AudioStreamPlayer3D = $SFXPlayer
@onready var laser_sfx_player: AudioStreamPlayer3D = $Body/Head/RayCast3D/Area3D/LaserMesh/LaserEndParticles/LaserSFXPlayer
@onready var barrier_sfx_player: AudioStreamPlayer = $BarrierCageArea/BarrierSFXPlayer

@export var shield_radius: float = 7.5
@onready var shield_body: StaticBody3D = $Shield
@onready var shield_mesh_solid: MeshInstance3D = $Shield/ShieldMeshSolid
@onready var shield_mesh_wispy: MeshInstance3D = $Shield/ShieldMeshWispy
@onready var shield_collider: CollisionShape3D = $Shield/CollisionShape3D
var shield_tween: Tween

var previous_phase: String

# Turrets
@export_group("Turrets")
var turret_spawns: Array:
	set(value):
		turret_spawns = value
		valid_spawns = turret_spawns.duplicate()
var valid_spawns: Array
var turret_look_target: Node3D
@export var turrets_to_spawn: int = 2
var spawned_turrets: Array = []

# Beam
@export_group("Laser Beam")
@onready var laser_area: Area3D = $Body/Head/RayCast3D/Area3D
@onready var laser_collider: CollisionShape3D = $Body/Head/RayCast3D/Area3D/LaserCollider
@onready var laser_mesh: MeshInstance3D = $Body/Head/RayCast3D/Area3D/LaserMesh
@onready var laser_particles: GPUParticles3D = $Body/Head/RayCast3D/Area3D/LaserMesh/LaserEndParticles
var beam_target: Vector3
@export var beam_sweeps_per_attack: int = 4
var beam_sweep_count: int = 0
@export var beam_sweep_delay: float = 0.7
@export var beam_collision_reset_delay: float = 1.2
var is_beam_tracking: bool = true  # HACK to prevent the beam from locking once it hits you
@export_subgroup("SFX")
@export var sfx_laser: AudioStream
@export var sfx_laser_impact: Array[AudioStream]

# Barrier Cage
@export_group("Barrier Cage")
@export var barrier_cage_radius: float = 24.0
@export var barrier_cage_reflect_force: float = 12.0
@export var barrier_cage_time: float = 12.0
@export var barrier_cage_material: Material
@onready var barrier_cage_area: Area3D = $BarrierCageArea
@onready var barrier_cage_collider: CollisionShape3D = $BarrierCageArea/CollisionShape3D
@onready var barrier_cage_mesh: MeshInstance3D = $BarrierCageArea/MeshInstance3D
@export_subgroup("SFX")
@export var sfx_barrier: AudioStream


func _ready() -> void:
	super()
	GRAVITY = 0
	head.rotate_x(PI)


func _physics_process(_delta: float) -> void:
	if barrier_sfx_player.playing:
		var target_pos_floor: Vector3 = target.global_position
		target_pos_floor.y = 0
		var target_dist: float = target_pos_floor.distance_to(Vector3.ZERO)
		target_dist = clamp(target_dist, 0, barrier_cage_radius)
		var dist_ratio: float = remap(target_dist, 0, barrier_cage_radius, 0.2, 1.0)
		barrier_sfx_player.volume_db = linear_to_db(dist_ratio)


func activate() -> void:
	super()
	anim_player.play("intro_look_at_player")
	show_shield()
	await anim_player.animation_finished
	state_chart.send_event("start_phase_1")


func toggle_stance() -> void:
	if phase_stance == Stance.AGGRESSIVE:
		phase_stance = Stance.DEFENSIVE
	elif phase_stance == Stance.DEFENSIVE:
		phase_stance = Stance.AGGRESSIVE


func select_attack() -> void:
	match current_phase:
		1:
			select_attack_phase_1()
		2:
			select_attack_phase_2()
		3:
			select_attack_phase_3()
		_:
			push_error("Invalid phase %s" % current_phase)


func select_attack_phase_1() -> void:
	return


func select_attack_phase_2() -> void:
	var _dist_to_target = self.global_position.distance_to(target.global_position)
	var possible_phases: Array[String]
	
	if phase_stance == Stance.DEFENSIVE:
		possible_phases = [
			"start_barrier_cage_attack",
		]
	elif phase_stance == Stance.AGGRESSIVE:
		possible_phases = [
			"start_laser_attack",
		]
	
	#if previous_phase:
		#possible_phases.erase(previous_phase)
	
	var new_phase: String = possible_phases[randi_range(0, possible_phases.size() - 1)]
	previous_phase = new_phase
	state_chart.send_event(new_phase)


func select_attack_phase_3() -> void:
	var _dist_to_target = self.global_position.distance_to(target.global_position)
	var possible_phases = [
		"start_spawn_turrets_attack",
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

func _on_died() -> void:
	if pit_boss.health_component.current_health == 0:
		await boss_death_slow_mo()
	eye_mesh.mesh.material.albedo_color = Color.PURPLE
	state_chart.send_event("death")
	state_chart.send_event("stop_moving")
	state_chart.send_event("deactivate")
	
	for turret in spawned_turrets:
		turret.destroy()

func _exit_tree() -> void:
	for turret in spawned_turrets:
		turret.destroy()
	
	if shield_mesh_solid.mesh.radius > 0.1:
		hide_shield()
	
	if laser_mesh.mesh.height > 0.1:
		var tween = get_tree().create_tween()
		tween.tween_property(laser_mesh.mesh, "height", 0.1, 0.4)
		tween.parallel().tween_property(laser_mesh, "position:z", 0.4, 0.4)
		tween.parallel().tween_property(laser_collider.shape, "height", 0.1, 0.4)
		tween.parallel().tween_property(laser_collider, "position:z", 0.4, 0.4)
		tween.parallel().tween_property(laser_mesh.mesh, "top_radius", 0.3, 0.8)
		tween.parallel().tween_property(laser_mesh.mesh, "bottom_radius", 0.3, 0.8)
		tween.parallel().tween_property(laser_particles, "scale", Vector3(1, 1, 1), 0.8)
		tween.parallel().tween_property(laser_collider.shape, "radius", 0.3, 0.8)
		laser_particles.emitting = false

func _on_health_hit_state_entered() -> void:
	eye_mesh.mesh.surface_get_material(0).albedo_color = Color.RED
	sprite.modulate = Color.RED
	await get_tree().create_timer(0.05).timeout
	state_chart.send_event("end_damage")

func _on_health_hit_state_exited() -> void:
	eye_mesh.mesh.surface_get_material(0).albedo_color = Color.WHITE


#### PHASE 1 ==========================
func _on_phase_1_state_entered() -> void:
	current_phase = 1
	phase_debug_label.text = "Phase 1"
	select_attack()

func _on_phase_1_state_physics_processing(delta: float) -> void:
	rotate_and_elevate(target.global_position, delta)


#### PHASE 2 ==========================
func _on_phase_2_state_entered() -> void:
	current_phase = 2
	phase_debug_label.text = "Phase 2"
	toggle_stance()

func _on_phase_2_state_physics_processing(_delta: float) -> void:
	pass

#### Phase 2 | Laser Beam
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
	laser_sfx_player.play()
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


func _on_laser_beam_startup_state_physics_processing(_delta: float) -> void:
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


func _on_phase_2_laser_beam_sweep_beam_state_entered() -> void:
	debug_state_label.text = "Laser Beam | Sweep"
	# TODO - add telegraphing to the sweep attack
	var tween = get_tree().create_tween()
	tween.tween_property(laser_mesh.mesh, "top_radius", 1.5, 0.8)
	tween.parallel().tween_property(laser_mesh.mesh, "bottom_radius", 1.5, 0.8)
	tween.parallel().tween_property(laser_particles, "scale", Vector3(3, 3, 3), 0.8)
	tween.parallel().tween_property(laser_collider.shape, "radius", 1.5, 0.8)
	
	# TODO - glow the laser to indicate sweep start
	await get_tree().create_timer(telegraph_time).timeout
	elevation_speed = deg_to_rad(elevation_speed_deg * 0.8)
	rotation_speed = deg_to_rad(rotation_speed_deg * 0.8)
	
	# Sweep towards the player's position
	beam_target = target.global_position

func _on_phase_2_laser_beam_sweep_beam_state_physics_processing(delta: float) -> void:
	if is_beam_tracking:
		beam_target = target.global_position
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
			laser_sfx_player.stop()
			state_chart.send_event("end_sweep")


func _on_phase_3_laser_beam_sweep_beam_state_entered() -> void:
	debug_state_label.text = "Laser Beam | Sweep"
	# TODO - add telegraphing to the sweep attack
	var tween = get_tree().create_tween()
	tween.tween_property(laser_mesh.mesh, "top_radius", 1.5, 0.8)
	tween.parallel().tween_property(laser_mesh.mesh, "bottom_radius", 1.5, 0.8)
	tween.parallel().tween_property(laser_particles, "scale", Vector3(3, 3, 3), 0.8)
	tween.parallel().tween_property(laser_collider.shape, "radius", 1.5, 0.8)
	
	# TODO - glow the laser to indicate sweep start
	await get_tree().create_timer(telegraph_time).timeout
	elevation_speed = deg_to_rad(elevation_speed_deg)
	rotation_speed = deg_to_rad(rotation_speed_deg)
	
	# Sweep towards the player's position
	beam_target = target.global_position

func _on_phase_3_laser_beam_sweep_beam_state_physics_processing(delta: float) -> void:
	if is_beam_tracking:
		beam_target = target.global_position
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
			laser_sfx_player.stop()
			state_chart.send_event("end_sweep")


func _on_laser_beam_recover_state_entered() -> void:
	debug_state_label.text = "Laser Beam | Recovering"
	
	laser_sfx_player.stop()
	var tween = get_tree().create_tween()
	tween.tween_property(laser_mesh.mesh, "height", 0.1, 0.4)
	tween.parallel().tween_property(laser_mesh, "position:z", 0.4, 0.4)
	tween.parallel().tween_property(laser_collider.shape, "height", 0.1, 0.4)
	tween.parallel().tween_property(laser_collider, "position:z", 0.4, 0.4)
	tween.parallel().tween_property(laser_mesh.mesh, "top_radius", 0.3, 0.8)
	tween.parallel().tween_property(laser_mesh.mesh, "bottom_radius", 0.3, 0.8)
	tween.parallel().tween_property(laser_particles, "scale", Vector3(1, 1, 1), 0.8)
	tween.parallel().tween_property(laser_collider.shape, "radius", 0.3, 0.8)
	
	await tween.finished
	laser_particles.emitting = false
	await get_tree().create_timer(attack_recovery_time).timeout
	
	select_attack()
	state_chart.send_event("end_recovery")


func _on_laser_hurtbox_body_entered(_body: Node3D) -> void:
	if _body == target and is_beam_tracking:
		target.health_component.damage(5)
		laser_sfx_player.stop()
		laser_sfx_player.stream = sfx_laser_impact.pick_random()
		laser_sfx_player.play()
		is_beam_tracking = false
		laser_area.set_deferred("monitoring", false)
		
		# FIXME - this is getting stuck narrow
		var tween = get_tree().create_tween()
		tween.parallel().tween_property(laser_mesh.mesh, "top_radius", 0.3, 0.2)
		tween.parallel().tween_property(laser_mesh.mesh, "bottom_radius", 0.3, 0.2)
		tween.parallel().tween_property(laser_particles, "scale", Vector3(1, 1, 1), 0.2)
		tween.parallel().tween_property(laser_collider.shape, "radius", 0.3, 0.2)
		
		await tween.finished
		
		await get_tree().create_timer(beam_collision_reset_delay).timeout
		
		tween = get_tree().create_tween()
		tween.tween_property(laser_mesh.mesh, "top_radius", 1.5, 0.2)
		tween.parallel().tween_property(laser_mesh.mesh, "bottom_radius", 1.5, 0.2)
		tween.parallel().tween_property(laser_particles, "scale", Vector3(3, 3, 3), 0.2)
		tween.parallel().tween_property(laser_collider.shape, "radius", 1.5, 0.2)
		await tween.finished
		
		laser_sfx_player.stop()
		laser_sfx_player.stream = sfx_laser
		laser_sfx_player.play()
		
		laser_area.set_deferred("monitoring", true)
		is_beam_tracking = true

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
	
	barrier_sfx_player.play()
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
	cage_tween.parallel().tween_property(barrier_sfx_player, "volume_db", linear_to_db(0.0), 0.8)
	await cage_tween.finished
	barrier_sfx_player.stop()
	
	barrier_cage_area.visible = false


func _on_barrier_cage_recover_state_entered() -> void:
	debug_state_label.text = "Barrier Cage | Recovering"
	await get_tree().create_timer(attack_recovery_time).timeout
	select_attack()
	state_chart.send_event("end_recovery")


#func _on_laser_beam_state_physics_processing(delta: float) -> void:
	#draw_debug_sphere(aim_ray.get_collision_point(), 0.5)


func _on_laser_beam_state_exited() -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(laser_mesh.mesh, "height", 0.1, 0.4)
	tween.parallel().tween_property(laser_mesh, "position:z", 0.4, 0.4)
	tween.parallel().tween_property(laser_collider.shape, "height", 0.1, 0.4)
	tween.parallel().tween_property(laser_collider, "position:z", 0.4, 0.4)
	tween.parallel().tween_property(laser_mesh.mesh, "top_radius", 0.3, 0.8)
	tween.parallel().tween_property(laser_mesh.mesh, "bottom_radius", 0.3, 0.8)
	tween.parallel().tween_property(laser_particles, "scale", Vector3(1, 1, 1), 0.8)
	tween.parallel().tween_property(laser_collider.shape, "radius", 0.3, 0.8)
	
	await tween.finished
	laser_particles.emitting = false


func _on_barrier_cage_state_exited() -> void:
	barrier_cage_area.monitoring = false
	
	var cage_tween = get_tree().create_tween()
	cage_tween.tween_property(barrier_cage_mesh.mesh, "top_radius", 42.0, 0.8)
	cage_tween.parallel().tween_property(barrier_cage_mesh.mesh, "bottom_radius", 42.0, 0.8)
	cage_tween.parallel().tween_property(barrier_cage_collider.shape, "radius", 42.0, 0.8)
	await cage_tween.finished
	
	barrier_cage_area.visible = false


#### PHASE 3 ==========================
func _on_phase_3_state_entered() -> void:
	current_phase = 3
	phase_debug_label.text = "Phase 3"
	hide_shield()
	select_attack()

func _on_phase_3_state_physics_processing(_delta: float) -> void:
	pass


#### Phase 3 | Spawn Turrets

func _on_turret_destroyed(turret: PitTurret) -> void:
	var turret_spawn = turret.get_parent()
	valid_spawns.push_back(turret_spawn)
	spawned_turrets.erase(turret)

func _on_spawn_turrets_targeting_state_entered() -> void:
	debug_state_label.text = "Spawn Turrets | Targeting"
	await get_tree().create_timer(attack_recovery_time).timeout
	state_chart.send_event("spawn_turrets")

func _on_spawn_turrets_targeting_state_physics_processing(delta: float) -> void:
	rotate_and_elevate(target.global_position, delta)

func _on_spawn_turrets_spawning_state_entered() -> void:
	debug_state_label.text = "Spawn Turrets | Spawning"
	
	for i in turrets_to_spawn:
		if spawned_turrets.size() >= turrets_to_spawn:
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
		spawned_turrets.push_back(turret)
	turret_look_target = null
	state_chart.send_event("stop_spawning")

func _on_spawn_turrets_recover_state_entered() -> void:
	debug_state_label.text = "Spawn Turrets | Recovering"
	valid_spawns = turret_spawns.duplicate()
	await get_tree().create_timer(attack_recovery_time).timeout
	select_attack()
	state_chart.send_event("end_recovery")


func show_shield() -> void:
	if shield_tween:
		shield_tween.kill()
	
	shield_tween = get_tree().create_tween()
	shield_tween.tween_property(shield_mesh_solid.mesh, "radius", shield_radius, 0.6)
	shield_tween.parallel().tween_property(shield_mesh_solid.mesh, "height", shield_radius, 0.6)
	shield_tween.parallel().tween_property(shield_mesh_wispy.mesh, "radius", shield_radius, 0.6)
	shield_tween.parallel().tween_property(shield_mesh_wispy.mesh, "height", shield_radius, 0.6)
	shield_tween.tween_callback(shield_collider.set_disabled.bind(false))


func hide_shield() -> void:
	if shield_tween:
		shield_tween.kill()
	
	shield_tween = get_tree().create_tween()
	shield_tween.tween_property(shield_mesh_solid.mesh, "radius", 0, 0.6)
	shield_tween.parallel().tween_property(shield_mesh_solid.mesh, "height", 0, 0.6)
	shield_tween.parallel().tween_property(shield_mesh_wispy.mesh, "radius", 0, 0.6)
	shield_tween.parallel().tween_property(shield_mesh_wispy.mesh, "height", 0, 0.6)
	shield_tween.tween_callback(shield_collider.set_disabled.bind(true))


func _on_defensive_state_entered() -> void:
	laser_sfx_player.stop()
	show_shield()


func _on_aggressive_state_entered() -> void:
	hide_shield()
