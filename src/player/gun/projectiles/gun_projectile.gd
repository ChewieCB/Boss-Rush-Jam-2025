extends BaseProjectile
class_name GunProjectile

## Affect both visual and collision
@export var thickness = 1

@onready var raycast: RayCast3D = $RayCast3D
@onready var life_timer: Timer = $LifeTimer

var projectile_speed = 100
var found_hitscal_col = false
var hitscan_col_point
var hitscan_col_normal
var current_dir

func _physics_process(delta: float) -> void:
	global_position -= transform.basis.z * projectile_speed * delta


func init(start_pos: Vector3, dir: Vector3, _damage: int, ricochet_count: int, _speed: float):
	life_timer.start()
	projectile_speed = _speed
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
	call_deferred("queue_free")

func ricochet():
	super()
	found_hitscal_col = false
	is_ricochet_shot = true
	init(global_position, current_dir.bounce(hitscan_col_normal), damage, ricochet_count_left - 1, projectile_speed)


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		body.health_component.damage(damage)
		damage_applied.emit()
		if found_hitscal_col:
			create_blood_splatter(hitscan_col_point, hitscan_col_normal)
	else:
		if found_hitscal_col:
			create_spark(hitscan_col_point, hitscan_col_normal)
	impacted.emit(true, global_position)
	if ricochet_count_left > 0 and found_hitscal_col:
		ricochet()
	else:
		destroyed.emit()
		call_deferred("queue_free")
