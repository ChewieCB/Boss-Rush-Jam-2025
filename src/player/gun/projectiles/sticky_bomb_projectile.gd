extends BaseProjectile

@export var delay_explosion_time = 2
@export var explosion_prefab: PackedScene
@export var explosion_vfx: PackedScene

@onready var life_timer: Timer = $LifeTimer
@onready var explode_timer: Timer = $ExplodeTimer
@onready var homing_area: Area3D = $HomingArea3D
@onready var homing_collision_shape: CollisionShape3D = $HomingArea3D/CollisionShape3D

var projectile_speed = 100
var current_dir
var max_range
var sticked = false
var explosion_damage = 0

func _physics_process(delta: float) -> void:
	if sticked:
		return

	if homing_locked_in and homing_target:
		var target_pos = homing_target.global_position
		if homing_target.get_node("BodyCenter"):
			target_pos = homing_target.get_node("BodyCenter").global_position
		var dir_to_target = global_position.direction_to(target_pos)
		look_at(global_position + dir_to_target)

	global_position -= transform.basis.z * projectile_speed * delta
	# global_position -= Vector3(0, 9.8, 0) * delta


func init(start_pos: Vector3, dir: Vector3, _damage: int, ricochet_count: int, _speed: float, _max_range: float):
	if homing_strength > 0:
		homing_area.monitoring = true
		homing_collision_shape.shape.radius = homing_strength
	life_timer.start()
	projectile_speed = _speed
	max_range = _max_range
	damage = 1
	explosion_damage = _damage
	current_dir = dir
	ricochet_count_left = ricochet_count
	look_at_from_position(start_pos, start_pos + dir)

	await get_tree().physics_frame
	await get_tree().physics_frame

func _on_life_timer_timeout() -> void:
	destroyed.emit()
	call_deferred("queue_free")

func _on_area_3d_body_entered(body: Node3D) -> void:
	if sticked:
		return
	if body is CharacterBody3D:
		if is_instance_valid(body):
			body.health_component.damage(damage)
			damage_applied.emit(true, global_position)
	else:
		if body is Shield:
			body.impact(self.global_position)
			body.health_component.damage(damage)
		elif body is RouletteBall or body is PitTurret:
			body.health_component.damage(damage)
	self.reparent.call_deferred(body)
	sticked = true
	life_timer.stop()
	explode_timer.start()
	impacted.emit(true, global_position)


func _on_homing_area_3d_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		homing_locked_in = true
		homing_target = body
		homing_area.set_deferred("monitoring", false)


func _on_explode_timer_timeout() -> void:
	var inst = explosion_prefab.instantiate()
	inst.init(explosion_damage)
	get_parent().add_child(inst)
	inst.global_position = global_position

	var vfx = explosion_vfx.instantiate()
	get_parent().add_child(vfx)
	vfx.global_position = global_position

	await get_tree().create_timer(0.25).timeout
	destroyed.emit()
	call_deferred("queue_free")
