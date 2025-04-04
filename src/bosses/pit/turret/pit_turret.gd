extends StaticBody3D
class_name PitTurret

signal destroyed(turret: PitTurret)

@export var TEMP_sfx_projectile: AudioStream

@export_group("SFX")
@export var sfx_turret_spawn: Array[AudioStream]
@export var sfx_turret_shot: Array[AudioStream]
@export var sfx_turret_death: Array[AudioStream]


@onready var body: Node3D = $Body
@onready var head: Node3D = $Body/Head
@onready var dome_mesh: MeshInstance3D = $Body/Dome
@onready var dome_collider: CollisionShape3D = $DomeCollider
@onready var aim_ray: RayCast3D = $Body/Head/RayCast3D
@onready var sfx_player: AudioStreamPlayer3D = $SFXPlayer1
@export var sfx_players: Array[AudioStreamPlayer3D]

@onready var debug_state_label: Label3D = $Label3D
@onready var state_chart: StateChart = $StateChart

@onready var health_component: HealthComponent = $HealthComponent

@export var elevation_speed_deg: float = 30.0
@export var rotation_speed_deg: float = 30.0

@export var target: Node3D

@onready var elevation_speed: float = deg_to_rad(elevation_speed_deg)
@onready var rotation_speed: float = deg_to_rad(rotation_speed_deg)

@export var explosion_scene: PackedScene

@export var projectile_scene: PackedScene
@export var projectile_spawns: Array[Marker3D]
@export var projectiles_per_attack: int = 3
@export var delay_per_projectile: float = 0.6


func _ready() -> void:
	spawn()


func spawn() -> void:
	sfx_player.stream = sfx_turret_spawn.pick_random()
	sfx_player.play()
	var tween = get_tree().create_tween()
	tween.tween_property(self, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_SINE)
	#tween.tween_property(self, "global_position:y", 0.0, 3.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)


func destroy() -> void:
	health_component.damage(999999)


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

	var elevation_sign = - sign(head.to_local(target_pos).y)
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


func _on_standard_attack_state_physics_processing(delta: float) -> void:
	rotate_and_elevate(delta, target.global_position + Vector3(0, 1.0, 0))


func _on_standard_attack_targeting_state_entered() -> void:
	debug_state_label.text = "Standard Attack | Targeting"

func _on_standard_attack_targeting_state_physics_processing(_delta: float) -> void:
	var aim_collision = aim_ray.get_collider()
	if aim_collision == target:
		state_chart.send_event("start_firing")


func _on_standard_attack_firing_state_entered() -> void:
	debug_state_label.text = "Standard Attack | Firing"

	for i in projectiles_per_attack:
		await get_tree().create_timer(delay_per_projectile).timeout
		for spawn in projectile_spawns:
			var projectile: TestProjectile = projectile_scene.instantiate()
			get_parent().get_parent().add_child(projectile)
			projectile.global_position = spawn.global_position
			projectile.look_at(target.global_position)
			projectile.projectile_speed = 42.0
			var _sfx_player = get_available_sfx_player()
			_sfx_player.stream = sfx_turret_shot.pick_random()
			_sfx_player.play()

	await get_tree().create_timer(delay_per_projectile).timeout
	state_chart.send_event("stop_firing")


func _on_standard_attack_recovering_state_entered() -> void:
	debug_state_label.text = "Standard Attack | Recovering"
	elevation_speed = deg_to_rad(elevation_speed_deg / 2)
	await get_tree().create_timer(0.6).timeout
	state_chart.send_event("end_recovery")


func _on_standard_attack_recovering_state_exited() -> void:
	elevation_speed = deg_to_rad(elevation_speed_deg)


func _on_health_component_health_changed(new_health: float, prev_health: float) -> void:
	if new_health < prev_health:
		if get_tree():
			dome_mesh.mesh.surface_get_material(0).albedo_color = Color.RED
			await get_tree().create_timer(0.05).timeout
			dome_mesh.mesh.surface_get_material(0).albedo_color = Color.WHITE


func _on_health_component_died() -> void:
	if get_tree() == null:
		return
	sfx_player.stream = sfx_turret_death.pick_random()
	sfx_player.play()
	var explosion_vfx = explosion_scene.instantiate()
	get_tree().get_root().add_child(explosion_vfx)
	explosion_vfx.global_position = self.global_position

	var tween = get_tree().create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.4).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(destroyed.emit.bind(self))
	tween.tween_callback(self.queue_free)


func get_available_sfx_player() -> AudioStreamPlayer3D:
	for player: AudioStreamPlayer3D in sfx_players:
		if player.playing:
			continue
		return player

	var players_ending_soon = sfx_players.duplicate()
	players_ending_soon.sort_custom(
		func(a, b):
			var a_time_left: float = a.stream.get_length() - a.get_playback_position()
			var b_time_left: float = b.stream.get_length() - b.get_playback_position()
			if a_time_left < b_time_left:
				return a
			return b
	)
	var fallback_player: AudioStreamPlayer3D = players_ending_soon.front()
	fallback_player.stop()

	return fallback_player
