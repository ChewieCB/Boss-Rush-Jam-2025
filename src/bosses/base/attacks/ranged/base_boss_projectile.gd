extends Area3D
class_name BaseBossProjectile
# Should remove this and use BaseProjectile instead, like Bartender's shotgun proj

@export var projectile_damage: float = 10.0
@export var projectile_speed: float = 50.0
@export var spark_effect: PackedScene

@onready var timer: Timer = $Timer
@onready var raycast: RayCast3D = $RayCast3D

var is_ricochet_shot = false
var ricochet_count_left = 0
var current_dir: Vector3
var found_hitscal_col = false
var hitscan_col_point: Vector3 = Vector3.ZERO
var hitscan_col_normal: Vector3 = Vector3.ZERO

func _ready() -> void:
	current_dir = - global_transform.basis.z.normalized()
	raycast.look_at(raycast.global_position + current_dir)

	await get_tree().physics_frame
	await get_tree().physics_frame

	if raycast.is_colliding():
		hitscan_col_point = raycast.get_collision_point()
		hitscan_col_normal = raycast.get_collision_normal()
		found_hitscal_col = true

func _physics_process(delta: float) -> void:
	current_dir = - transform.basis.z.normalized()
	global_position -= transform.basis.z * projectile_speed * delta

func init(_damage: float, _speed: float):
	projectile_damage = _damage
	projectile_speed = _speed

func ricochet():
	timer.stop()
	timer.start()
	ricochet_count_left -= 1
	found_hitscal_col = false
	is_ricochet_shot = true
	var new_dir = current_dir.bounce(hitscan_col_normal)
	look_at_from_position(global_position, global_position + new_dir)

	await get_tree().physics_frame
	await get_tree().physics_frame

	if raycast.is_colliding():
		hitscan_col_point = raycast.get_collision_point()
		hitscan_col_normal = raycast.get_collision_normal()
		found_hitscal_col = true
	raycast.rotation = Vector3.ZERO

func create_spark(pos: Vector3, normal: Vector3):
	if spark_effect == null:
		return

	var spark_inst = spark_effect.instantiate()
	get_parent().add_child(spark_inst)
	spark_inst.global_position = pos

	if normal.is_equal_approx(Vector3.DOWN):
		spark_inst.rotation_degrees.x = -90
	elif normal.is_equal_approx(Vector3.UP):
		spark_inst.rotation_degrees.x = 90
	else:
		spark_inst.look_at(pos + normal, Vector3.UP)

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		body.health_component.damage(projectile_damage)
	# TODO - make this have collision exception based on who fired it
	elif body is BossCore:
		pass
	else:
		create_spark(global_position, body.global_position.direction_to(global_position))
		if ricochet_count_left > 0 and found_hitscal_col:
			ricochet()
		else:
			queue_free()

func destroy() -> void:
	queue_free()

func _on_timer_timeout() -> void:
	destroy()
