extends BaseBullet
class_name BartenderShotgunProjectile

@onready var push_force = 20
@onready var raycast: RayCast3D = $RayCast3D
@onready var life_timer: Timer = $LifeTimer
@onready var hit_area: Area3D = $Area3D

func _physics_process(delta: float) -> void:
	global_position -= transform.basis.z * projectile_speed * delta


func init(start_pos: Vector3, dir: Vector3, _damage: int, ricochet_count: int, _speed: float, _max_range: float = 500):
	life_timer.start()
	projectile_speed = _speed
	damage = _damage
	ricochet_count_left = ricochet_count
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
	if ricochet_count_left > 0 and found_hitscal_col:
		ricochet()
	else:
		destroyed.emit(false)
		call_deferred("queue_free")


func ricochet():
	super ()
	found_hitscal_col = false
	is_ricochet_shot = true
	init(global_position, current_dir.bounce(hitscan_col_normal), damage, ricochet_count_left - 1, projectile_speed)
	raycast.rotation = Vector3.ZERO
	life_timer.start()


func parried():
	super ()
	const PARRIED_DMG_MULT = 10
	const PARRIED_SPD_MULT = 2
	damage = damage * PARRIED_DMG_MULT
	projectile_speed = projectile_speed * PARRIED_SPD_MULT
	hit_area.set_collision_mask_value(3, true)
	current_dir = - current_dir
	look_at(global_position + current_dir, Vector3.UP)
	life_timer.start()
