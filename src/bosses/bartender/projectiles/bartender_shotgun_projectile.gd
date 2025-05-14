extends BaseProjectile

@onready var push_force = 20
@onready var raycast: RayCast3D = $RayCast3D
@onready var life_timer: Timer = $LifeTimer

func _physics_process(delta: float) -> void:
	global_position -= transform.basis.z * projectile_speed * delta


func init(start_pos: Vector3, dir: Vector3, _damage: int, _speed: float):
	life_timer.start()
	projectile_speed = _speed
	damage = _damage
	current_dir = dir.normalized()
	look_at_from_position(start_pos, start_pos + dir)

	await get_tree().physics_frame
	await get_tree().physics_frame

	if raycast.is_colliding():
		hitscan_col_normal = raycast.get_collision_normal()
		found_hitscal_col = true

func _on_life_timer_timeout() -> void:
	call_deferred("queue_free")

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		body.health_component.damage(damage)
		# Push player away
		if body is Player:
			var push_dir = Vector3(current_dir.x, 0, current_dir.z)
			body.apply_impulse_to_player(push_dir * push_force)
		if found_hitscal_col:
			create_blood_splatter(global_position, hitscan_col_normal)
	else:
		if body is Shield:
			body.impact(self.global_position)
			body.health_component.damage(damage)
		elif body is RouletteBall or body is PitTurret:
			body.health_component.damage(damage)
		if found_hitscal_col:
			create_spark(global_position, hitscan_col_normal)
	call_deferred("queue_free")