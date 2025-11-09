extends BaseProjectile

@export var delay_explosion_time = 2
@export var explosion_prefab: PackedScene
@export var explosion_vfx: PackedScene

@onready var raycast: RayCast3D = $RayCast3D
@onready var life_timer: Timer = $LifeTimer
@onready var explode_timer: Timer = $ExplodeTimer
@onready var homing_area: Area3D = $HomingArea3D
@onready var homing_collision_shape: CollisionShape3D = $HomingArea3D/CollisionShape3D
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var trail: Trail3D = $Trail/Trail3D

const CONTACT_DAMAGE = 1

var sticked = false
var explosion_damage = 0

func _ready() -> void:
	super ()

func _process(delta: float) -> void:
	super (delta)

func _physics_process(delta: float) -> void:
	if sticked:
		return

	if homing_locked_in and homing_target:
		var target_pos = homing_target.global_position
		if homing_target.get_node("BodyCenter"):
			target_pos = homing_target.get_node("BodyCenter").global_position
		var dir_to_target = global_position.direction_to(target_pos)
		look_at(global_position + dir_to_target)
	
	velocity = -transform.basis.z * projectile_speed * delta
	global_position += velocity 
	travelled_distance += projectile_speed * delta


func init(start_pos: Vector3, dir: Vector3, _damage: int, ricochet_count: int, _speed: float, _max_range: float):
	if homing_strength > 0:
		homing_area.monitoring = true
		homing_collision_shape.shape.radius = homing_strength
	life_timer.start()
	projectile_speed = _speed
	max_range = _max_range
	damage = CONTACT_DAMAGE
	explosion_damage = _damage
	current_dir = dir
	ricochet_count_left = ricochet_count
	look_at_from_position(start_pos, start_pos + dir)

	await get_tree().physics_frame
	await get_tree().physics_frame

	if raycast.is_colliding():
		hitscan_col_point = raycast.get_collision_point()
		hitscan_col_normal = raycast.get_collision_normal()
		found_hitscal_col = true

func ricochet():
	super ()
	found_hitscal_col = false
	is_ricochet_shot = true
	init(global_position, current_dir.bounce(hitscan_col_normal), explosion_damage, ricochet_count_left - 1, projectile_speed, max_range)


func _on_life_timer_timeout() -> void:
	destroyed.emit()
	stop_elemental_particles()
	call_deferred("queue_free")

func _on_area_3d_body_entered(body: Node3D) -> void:
	if sticked:
		return
	if body is CharacterBody3D:
		if is_instance_valid(body):
			before_damage_applied.emit(body, self)
			body.health_component.damage(damage)
			damage_applied.emit(damage, true, global_position)
	else:
		if body is Shield:
			body.impact(self.global_position)
			body.health_component.damage(damage)
		elif "health_component" in body:
			body.health_component.damage(damage)
	self.reparent.call_deferred(body)
	sticked = true
	life_timer.stop()
	explode_timer.start()
	impacted.emit(self, true, global_position)


func _on_homing_area_3d_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		homing_locked_in = true
		homing_target = body
		homing_area.set_deferred("monitoring", false)


func _on_explode_timer_timeout() -> void:
	var inst: ExplosionDamageArea = explosion_prefab.instantiate()
	var calculated_explosion_damage = calculate_explosion_damage()
	inst.init(calculated_explosion_damage)
	get_parent().add_child(inst)
	inst.global_position = global_position

	var vfx = explosion_vfx.instantiate()
	get_parent().add_child(vfx)
	vfx.global_position = global_position

	if ricochet_count_left > 0 and found_hitscal_col:
		sticked = false
		self.reparent.call_deferred(get_tree().get_root())
		ricochet()
	else:
		await get_tree().create_timer(0.25).timeout
		destroyed.emit()
		stop_elemental_particles()
		call_deferred("queue_free")

func change_bullet_color(_new_color: Color):
	super (_new_color)
	if color_changed_count > 1:
		mesh.mesh.material.albedo_color = mesh.mesh.material.albedo_color.lerp(_new_color, 0.5)
		mesh.mesh.material.emission = mesh.mesh.material.emission.lerp(_new_color, 0.5)
		trail.material_override.albedo_color = trail.material_override.albedo_color.lerp(_new_color, 0.5)
		trail.material_override.emission = trail.material_override.emission.lerp(_new_color, 0.5)
	else:
		mesh.mesh.material.albedo_color = _new_color
		mesh.mesh.material.emission = _new_color
		trail.material_override.albedo_color = Color(_new_color.r, _new_color.g, _new_color.b, 0.7)
		trail.material_override.emission = _new_color


func calculate_explosion_damage():
	var rand_damage_mod = get_damage_variance_modifier(explosion_damage)
	var calculated_damage = explosion_damage + rand_damage_mod
	# Crit
	var roll = randi_range(1, 100)
	var roll_target = int(crit_chance * 100)
	if roll <= roll_target:
		calculated_damage = calculated_damage * GameManager.player.current_stats[StatusEffect.PlayerStatEnum.CRITICAL_HIT_DAMAGE_MULTIPLIER]
		owner_gun.crit_damage(calculated_damage)
	return calculated_damage
