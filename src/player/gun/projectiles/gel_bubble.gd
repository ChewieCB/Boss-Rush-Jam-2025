extends BaseProjectile

@export var stick_time = 1
@export var max_scale = 3
@export var grow_speed = 100
@export var projectile_speed_decay = 20
@export var min_delay_time = 0.1
@export var max_delay_time = 0.5

@onready var raycast: RayCast3D = $RayCast3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var life_timer: Timer = $LifeTimer
@onready var homing_area: Area3D = $HomingArea3D
@onready var homing_collision_shape: CollisionShape3D = $HomingArea3D/CollisionShape3D

## Each bubble has a random delayed time before it start moving
var delayed = true
var start_deflate = false
var deflate_speed = 30

func _ready() -> void:
	super ()
	delayed = true
	mesh_instance.visible = false
	mesh_instance.scale = Vector3.ONE * 0.01
	var delay_time = randf_range(min_delay_time, max_delay_time)
	await get_tree().create_timer(delay_time).timeout
	# Reset lifetime so delayed time doesnt affect it
	life_timer.start()
	delayed = false
	mesh_instance.visible = true


func _process(delta: float) -> void:
	super (delta)


func _physics_process(delta: float) -> void:
	if delayed:
		return

	if mesh_instance.scale.x < max_scale:
		mesh_instance.scale += Vector3.ONE * grow_speed * delta

	if projectile_speed > 0:
		projectile_speed -= projectile_speed_decay * delta


	if homing_locked_in and homing_target:
		var target_pos = homing_target.global_position
		if homing_target.get_node("BodyCenter"):
			target_pos = homing_target.get_node("BodyCenter").global_position
		var dir_to_target = global_position.direction_to(target_pos)
		look_at(global_position + dir_to_target)

	global_position -= transform.basis.z * projectile_speed * delta
	travelled_distance += projectile_speed * delta
	# When bubble stop moving forward, make it flight up
	global_position += Vector3.UP * 1 * delta


func init(start_pos: Vector3, dir: Vector3, _damage: int, ricochet_count: int, _speed: float, _max_range: float):
	if homing_strength > 0:
		homing_area.monitoring = true
		homing_collision_shape.shape.radius = homing_strength
	life_timer.start()
	projectile_speed = _speed
	max_range = _max_range
	var rand_damage_mod = get_damage_variance_modifier(_damage)
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


func _on_life_timer_timeout() -> void:
	destroyed.emit()
	call_deferred("queue_free")
