extends BaseProjectile
class_name GunProjectile

@onready var raycast: RayCast3D = $RayCast3D
@onready var life_timer: Timer = $LifeTimer

@onready var homing_area: Area3D = $HomingArea3D
@onready var homing_collision_shape: CollisionShape3D = $HomingArea3D/CollisionShape3D

func _ready() -> void:
	super ()

func _process(delta: float) -> void:
	super (delta)

func _physics_process(delta: float) -> void:
	if homing_locked_in and homing_target:
		var target_pos = homing_target.global_position
		if homing_target.get_node("BodyCenter"):
			target_pos = homing_target.get_node("BodyCenter").global_position
		var dir_to_target = global_position.direction_to(target_pos)
		look_at(global_position + dir_to_target)
	global_position -= transform.basis.z * projectile_speed * delta
	travelled_distance += projectile_speed * delta


func init(start_pos: Vector3, dir: Vector3, _damage: int, ricochet_count: int, _speed: float, _max_range: float):
	if homing_strength > 0:
		homing_area.monitoring = true
		homing_collision_shape.shape.radius = homing_strength
	life_timer.start()
	projectile_speed = _speed
	max_range = _max_range
	var rand_damage_mod = get_damamge_variance_modifier(_damage)
	damage = _damage + rand_damage_mod
	current_dir = dir
	ricochet_count_left = ricochet_count
	look_at_from_position(start_pos, start_pos + dir)

	await get_tree().physics_frame
	await get_tree().physics_frame

	if raycast.is_colliding():
		hitscan_col_point = raycast.get_collision_point()
		hitscan_col_normal = raycast.get_collision_normal()
		found_hitscal_col = true

func _on_life_timer_timeout() -> void:
	destroyed.emit()
	call_deferred("queue_free")

func ricochet():
	super ()
	found_hitscal_col = false
	is_ricochet_shot = true
	init(global_position, current_dir.bounce(hitscan_col_normal), damage, ricochet_count_left - 1, projectile_speed, max_range)

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		if is_instance_valid(body):
			before_damage_applied.emit(body, self)
			body.health_component.damage(damage)
			damage_applied.emit(damage, true, global_position)
			ricochet_count_left = 0
		if found_hitscal_col:
			create_blood_splatter(hitscan_col_point, hitscan_col_normal)
	else:
		if body is Shield:
			body.impact(self.global_position)
			body.health_component.damage(damage)
		elif "health_component" in body:
			body.health_component.damage(damage)
		if found_hitscal_col:
			create_spark(hitscan_col_point, hitscan_col_normal)
			create_bullet_decal(hitscan_col_point, hitscan_col_normal)
	impacted.emit(self, true, global_position)
	if ricochet_count_left > 0 and found_hitscal_col:
		ricochet()
	else:
		destroyed.emit()
		call_deferred("queue_free")


func _on_homing_area_3d_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		homing_locked_in = true
		homing_target = body
		homing_area.set_deferred("monitoring", false)
