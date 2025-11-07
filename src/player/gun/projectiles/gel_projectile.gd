extends BaseBullet
class_name GelProjectile

@export var stick_time = 1
@export var max_scale = 3
@export var grow_speed = 100
@export var deflate_accel = 10
@export var deflate_speed = 1

@onready var raycast: RayCast3D = $RayCast3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var life_timer: Timer = $LifeTimer
@onready var stick_timer: Timer = $StickTimer
@onready var homing_area: Area3D = $HomingArea3D
@onready var homing_collision_shape: CollisionShape3D = $HomingArea3D/CollisionShape3D
@onready var impact_shape: CollisionShape3D = $Area3D/CollisionShape3D
@onready var homing_shape: CollisionShape3D = $HomingArea3D/CollisionShape3D

# When gel projectile collide, if the hitscan_col_point is valid and not too
# far from current global_position, snap to hitscan_col_point so it look better.
const SNAP_STICK_DISTANCE = 5

var sticked = false
var start_deflate = false
var active = false

func _ready() -> void:
	return


func _process(delta: float) -> void:
	super (delta)


func _physics_process(delta: float) -> void:
	if not active:
		return

	if sticked:
		if start_deflate:
			if mesh_instance.scale.x > 0:
				deflate_speed += deflate_accel * delta
				mesh_instance.scale -= Vector3.ONE * deflate_speed * delta
			else:
				mesh_instance.visible = false
		return

	if mesh_instance.scale.x < max_scale:
		mesh_instance.scale += Vector3.ONE * grow_speed * delta

	if homing_locked_in and homing_target:
		var target_pos = homing_target.global_position
		if homing_target.get_node("BodyCenter"):
			target_pos = homing_target.get_node("BodyCenter").global_position
		var dir_to_target = global_position.direction_to(target_pos)
		look_at(global_position + dir_to_target)

	# Make it fly forward
	global_position -= transform.basis.z * projectile_speed * delta
	travelled_distance += projectile_speed * delta


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

func ricochet():
	super ()
	found_hitscal_col = false
	is_ricochet_shot = true
	init(global_position, current_dir.bounce(hitscan_col_normal), damage, ricochet_count_left - 1, projectile_speed, max_range)

func split(split_count: int, split_spread_radius: float, _has_pos: bool, _pos: Vector3):
	if splitted:
		return

	var center_dir = - current_dir
	var new_pos = global_position
	if found_hitscal_col:
		center_dir = hitscan_col_normal
	if _has_pos:
		new_pos = _pos

	for i in range(split_count):
		if not is_instance_valid(self):
			return
		var new_inst = GameManager.object_pooling_manager.get_pooled_object(ObjectPoolingManager.PooledObjectEnum.GEL_STREAM_PROJECTILE)
		var new_dir = GunUtils.get_spread_direction(center_dir, split_spread_radius)
		# Splitted bullet CAN NOT ricochet or split again
		new_inst.activate(new_pos, new_dir)
		new_inst.splitted = true
		new_inst.init(new_pos, new_dir, int(damage / split_count), 0, projectile_speed, max_range)

func _on_area_3d_body_entered(body: Node3D) -> void:
	if sticked:
		return

	var calculated_damage = calculate_bullet_damage()
	if body is CharacterBody3D:
		if is_instance_valid(body):
			before_damage_applied.emit(body, self)
			calculated_damage = calculate_bullet_damage() # Recalculate damage after before_damage_applied effect
			apply_damage_to_health_component(body.health_component, calculated_damage)
			damage_applied.emit(calculated_damage, true, global_position)
			hit_boss = true
	else:
		if body is Shield:
			body.impact(self.global_position)
			apply_damage_to_health_component(body.health_component, calculated_damage)
			hit_boss = true
		elif "health_component" in body:
			apply_damage_to_health_component(body.health_component, calculated_damage)
			hit_boss = true
	self.reparent.call_deferred(body)
	sticked = true
	impacted.emit(self, true, global_position)
	life_timer.stop()
	stick_timer.start(stick_time)
	if found_hitscal_col:
		if global_position.distance_to(hitscan_col_point) < SNAP_STICK_DISTANCE:
			global_position = hitscan_col_point


func _on_homing_area_3d_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		homing_locked_in = true
		homing_target = body
		homing_area.set_deferred("monitoring", false)


func _on_life_timer_timeout() -> void:
	destroyed.emit(hit_boss)
	deactivate()


func _on_stick_timer_timeout() -> void:
	# This must be less than normal lifetime
	const STICKED_NO_RICOCHET_LIFETIME = 3
	if ricochet_count_left == 0:
		life_timer.start(STICKED_NO_RICOCHET_LIFETIME)
	else:
		life_timer.start()
	if ricochet_count_left > 0 and found_hitscal_col:
		sticked = false
		self.reparent.call_deferred(GameManager.object_pooling_manager)
		ricochet()
	else:
		stop_elemental_particles()
		start_deflate = true

func change_bullet_color(_new_color: Color):
	super (_new_color)
	if color_changed_count > 1:
		mesh_instance.mesh.material.albedo_color = mesh_instance.mesh.material.albedo_color.lerp(_new_color, 0.5)
	else:
		mesh_instance.mesh.material.albedo_color = _new_color

func stop_elemental_particles():
	for elem in elemental_emitting_vfx:
		if elem:
			elem.deactivate()

func activate(start_pos: Vector3, dir: Vector3) -> void:
	look_at_from_position(start_pos, start_pos + dir)
	sticked = false
	start_deflate = false
	mesh_instance.scale = Vector3.ONE
	mesh_instance.visible = true
	deflate_speed = 1
	homing_locked_in = false
	homing_target = null
	color_changed_count = 0
	life_time = 0
	travelled_distance = 0
	spawn_pos = global_position
	is_ricochet_shot = false
	splitted = false

	crit_chance = GameManager.player.current_stats[StatusEffect.PlayerStatEnum.CRITICAL_HIT_CHANCE]
	for elem in elemental_emitting_vfx:
		if elem:
			elem.activate()

	global_position = start_pos
	active = true
	visible = true
	impact_shape.call_deferred("set_disabled", false)
	homing_shape.call_deferred("set_disabled", false)
	raycast.set_deferred("enabled", false)
	set_process(true)
	set_physics_process(true)
	
func deactivate() -> void:
	if GameManager.object_pooling_manager:
		self.reparent.call_deferred(GameManager.object_pooling_manager)
	visible = false
	active = false
	ricochet_count_left = 0
	life_timer.stop()
	stick_timer.stop()
	impact_shape.call_deferred("set_disabled", true)
	homing_shape.call_deferred("set_disabled", true)
	raycast.set_deferred("enabled", true)
	stop_elemental_particles()
	set_process(false)
	set_physics_process(false)