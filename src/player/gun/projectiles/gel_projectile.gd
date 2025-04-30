extends BaseProjectile

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

var projectile_speed = 100
var found_hitscal_col = false
var hitscan_col_point
var hitscan_col_normal
var current_dir
var max_range
var sticked = false
var start_deflate = false


func _physics_process(delta: float) -> void:
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


func init(start_pos: Vector3, dir: Vector3, _damage: int, ricochet_count: int, _speed: float, _max_range: float):
	if homing_strength > 0:
		homing_area.monitoring = true
		homing_collision_shape.shape.radius = homing_strength
	life_timer.start()
	projectile_speed = _speed
	max_range = _max_range
	var rand_damage_mod = int(randf_range(-_damage / 3.0, _damage / 3.0))
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

func ricochet():
	super ()
	found_hitscal_col = false
	is_ricochet_shot = true
	init(global_position, current_dir.bounce(hitscan_col_normal), damage, ricochet_count_left - 1, projectile_speed, max_range)


func _on_area_3d_body_entered(body: Node3D) -> void:
	if sticked:
		return
	if body is CharacterBody3D:
		if is_instance_valid(body):
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
	impacted.emit(true, global_position)
	life_timer.stop()
	stick_timer.start(stick_time)


func _on_homing_area_3d_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		homing_locked_in = true
		homing_target = body
		homing_area.set_deferred("monitoring", false)


func _on_life_timer_timeout() -> void:
	destroyed.emit()
	call_deferred("queue_free")


func _on_stick_timer_timeout() -> void:
	life_timer.start()
	if ricochet_count_left > 0 and found_hitscal_col:
		sticked = false
		self.reparent.call_deferred(get_tree().get_root())
		ricochet()
	else:
		start_deflate = true
