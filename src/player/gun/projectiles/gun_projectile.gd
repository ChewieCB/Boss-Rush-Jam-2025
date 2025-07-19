extends BaseProjectile
class_name GunProjectile

@export var gravity_modifier = 0.0

@onready var raycast: RayCast3D = $RayCast3D
@onready var life_timer: Timer = $LifeTimer
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var trail: Trail3D = $Trail/Trail3D

@onready var homing_area: Area3D = $HomingArea3D
@onready var homing_collision_shape: CollisionShape3D = $HomingArea3D/CollisionShape3D


# Gravity stuff
const MAX_GRAVITY_PITCH = deg_to_rad(90.0)
const ROTATE_RATE_MODIFIER = 0.25
const GRAVITY_IGNORE_AFTER_RICO_TIME = 0.2

var gravity_accel = 0
var gravity_free_timer = 0.2

func _ready() -> void:
	super ()

func _process(delta: float) -> void:
	super (delta)
	gravity_free_timer += delta

func _physics_process(delta: float) -> void:
	if homing_locked_in and homing_target:
		gravity_modifier = 0
		gravity_accel = 0
		# HACK catch for minions/boss sub-forms that die mid-ticka
		if not homing_target:
			return
		var target_pos = homing_target.global_position
		if homing_target.get_node("BodyCenter"):
			target_pos = homing_target.get_node("BodyCenter").global_position
		var dir_to_target = global_position.direction_to(target_pos)
		look_at(global_position + dir_to_target)
	global_position -= transform.basis.z * projectile_speed * delta
	travelled_distance += projectile_speed * delta


	if gravity_modifier > 0 and gravity_free_timer > GRAVITY_IGNORE_AFTER_RICO_TIME:
		gravity_accel += GRAVITY_FORCE * gravity_modifier * delta
		global_position += Vector3(0, 1, 0) * gravity_accel * delta
		# Pitch downward based on accumulated gravity
		var pitch_angle = gravity_accel * ROTATE_RATE_MODIFIER * delta # radians per frame
		var dot = - raycast.global_transform.basis.z.dot(Vector3.DOWN)
		# If dot > 0.99, it point almost downward. Downward == 1
		# Only rotate if not point downward
		if dot < 0.99:
			raycast.rotate_object_local(Vector3(1, 0, 0), pitch_angle)

		if raycast.is_colliding():
			hitscan_col_point = raycast.get_collision_point()
			hitscan_col_normal = raycast.get_collision_normal()
			found_hitscal_col = true
		else:
			found_hitscal_col = false

func init(start_pos: Vector3, dir: Vector3, _damage: int, ricochet_count: int, _speed: float, _max_range: float):
	if homing_strength > 0:
		homing_area.monitoring = true
		homing_collision_shape.shape.radius = homing_strength
	life_timer.start()
	projectile_speed = _speed
	max_range = _max_range
	damage = _damage
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
	stop_elemental_particles()
	call_deferred("queue_free")

func ricochet():
	super ()
	gravity_free_timer = 0
	found_hitscal_col = false
	is_ricochet_shot = true
	init(global_position, current_dir.bounce(hitscan_col_normal), damage, ricochet_count_left - 1, projectile_speed, max_range)
	raycast.rotation = Vector3.ZERO
	gravity_accel = 0

func _on_area_3d_body_entered(body: Node3D) -> void:
	var calculated_damage = calculate_bullet_damage()
	if body is CharacterBody3D:
		if is_instance_valid(body):
			before_damage_applied.emit(body, self)
			body.health_component.damage(calculated_damage)
			damage_applied.emit(calculated_damage, true, global_position)
			ricochet_count_left = 0
		if found_hitscal_col:
			create_blood_splatter(hitscan_col_point, hitscan_col_normal)
	else:
		if "health_component" in body:
			if body is Shield:
				body.impact(self.global_position)
			body.health_component.damage(calculated_damage)
			damage_applied.emit(calculated_damage, true, global_position)
		if found_hitscal_col and gravity_accel == 0:
			create_spark(hitscan_col_point, hitscan_col_normal)
			create_bullet_decal(hitscan_col_point, hitscan_col_normal)
		else:
			create_spark(global_position, Vector3.UP)
			create_bullet_decal(global_position, Vector3.UP)
	impacted.emit(self, true, global_position)
	if ricochet_count_left > 0 and found_hitscal_col:
		ricochet()
	else:
		stop_elemental_particles()
		destroyed.emit()
		call_deferred("queue_free")


func _on_homing_area_3d_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		homing_locked_in = true
		homing_target = body
		homing_area.set_deferred("monitoring", false)

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

func applied_elemental_vfx(status_effect: BossCore.BossStatusEffect):
	# Wait a bit to make the effect look better
	await get_tree().create_timer(0.1).timeout
	if status_effect == BossCore.BossStatusEffect.BURNING:
		var element_vfx_node = elemental_emitting_vfx[int(status_effect) - 1]
		if element_vfx_node:
			element_vfx_node.visible = true
			if element_vfx_node.has_method("turn_on"):
				element_vfx_node.turn_on()


func stop_elemental_particles():
	for elem in elemental_emitting_vfx:
		if elem and elem.has_method("queue_free_after_time"):
			elem.queue_free_after_time()
