extends RigidBody3D
class_name BallProjectile

@export var spark_effect: PackedScene
@export var generic_blood_splatter: PackedScene

@onready var raycast: RayCast3D = $RayCast3D
@onready var life_timer: Timer = $LifeTimer
@onready var homing_area: Area3D = $HomingArea3D
@onready var homing_collision_shape: CollisionShape3D = $HomingArea3D/CollisionShape3D

signal damage_applied
signal impacted
signal destroyed

var damage
var projectile_speed = 100
var current_dir
var owner_gun: Gun
var homing_strength = 0 # radius to search for enemy
var homing_locked_in = false
var homing_target = null
var ricochet_count_left = 0
var max_range

const HOMING_FORCE_COEFFICIENT = 1200

func init(start_pos: Vector3, dir: Vector3, _damage: int, _ricochet_count: int, _speed: float, _max_range: float):
	if homing_strength > 0:
		homing_area.monitoring = true
		homing_collision_shape.shape.radius = homing_strength
	life_timer.start()
	projectile_speed = _speed
	damage = _damage
	ricochet_count_left = _ricochet_count
	max_range = _max_range
	current_dir = dir.normalized()
	look_at_from_position(start_pos, start_pos + dir)

	await get_tree().physics_frame
	await get_tree().physics_frame

	apply_impulse(current_dir * projectile_speed, Vector3.ZERO)


func _physics_process(delta: float) -> void:
	if homing_locked_in and homing_target:
		var target_pos = homing_target.global_position
		if homing_target.get_node("BodyCenter"):
			target_pos = homing_target.get_node("BodyCenter").global_position
		var dir_to_target = global_position.direction_to(target_pos).normalized()
		apply_force(dir_to_target * HOMING_FORCE_COEFFICIENT * homing_strength * delta, Vector3.ZERO)


func _on_life_timer_timeout() -> void:
	destroyed.emit()
	call_deferred("queue_free")

func ricochet():
	init(global_position, current_dir, damage, ricochet_count_left - 1, projectile_speed, max_range)


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		body.health_component.damage(damage)
		damage_applied.emit(true, global_position)
		create_blood_splatter(global_position, Vector3.UP)
	else:
		if body is Shield:
			body.impact(self.global_position)
			body.health_component.damage(damage)
		elif body is RouletteBall:
			body.health_component.damage(damage)
		create_spark(global_position, Vector3.UP)
	impacted.emit(true, global_position)
	if ricochet_count_left > 0:
		ricochet()

func create_spark(pos: Vector3, normal: Vector3):
	var spark_inst = spark_effect.instantiate()
	get_parent().add_child(spark_inst)
	spark_inst.global_position = pos

	if normal.is_equal_approx(Vector3.DOWN):
		spark_inst.rotation_degrees.x = -90
	elif normal.is_equal_approx(Vector3.UP):
		spark_inst.rotation_degrees.x = 90
	else:
		spark_inst.look_at(pos + normal, Vector3.UP)

func create_blood_splatter(pos: Vector3, normal: Vector3):
	var blood_inst = generic_blood_splatter.instantiate()
	get_parent().add_child(blood_inst)
	blood_inst.global_position = pos

	if normal.is_equal_approx(Vector3.DOWN):
		blood_inst.rotation_degrees.x = -90
	elif normal.is_equal_approx(Vector3.UP):
		blood_inst.rotation_degrees.x = 90
	else:
		blood_inst.look_at(pos + normal, Vector3.UP)


func _on_homing_area_3d_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		homing_locked_in = true
		homing_target = body
		homing_area.set_deferred("monitoring", false)
