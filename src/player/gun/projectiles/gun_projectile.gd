extends BaseProjectile
class_name GunProjectile


## Affect both visual and collision
@export var thickness = 1

@onready var raycast: RayCast3D = $RayCast3D

signal damage_applied
signal impacted
signal destroyed

var projectile_speed = 100
var damage = 1
var found_hitscal_col = false
var hitscan_col_point = Vector3.ZERO
var hitscan_col_normal = Vector3.ZERO

func _physics_process(delta: float) -> void:
	global_position -= transform.basis.z * projectile_speed * delta


func init(pos1: Vector3, pos2: Vector3, _damage: int, _speed: float):
	projectile_speed = _speed
	damage = _damage
	look_at_from_position(pos1, pos2)

	await get_tree().physics_frame
	await get_tree().physics_frame

	if raycast.is_colliding():
		hitscan_col_point = raycast.get_collision_point()
		hitscan_col_normal = raycast.get_collision_normal()
		found_hitscal_col = true

func _on_life_timer_timeout() -> void:
	destroyed.emit()
	call_deferred("queue_free")


func _on_area_3d_body_entered(body: Node3D) -> void:
	projectile_speed = 0
	if body is CharacterBody3D:
		body.health_component.damage(damage)
		damage_applied.emit()
		if found_hitscal_col:
			create_blood_splatter(hitscan_col_point, hitscan_col_normal)
	else:
		if body is Shield:
			body.impact(self.global_position)
			body.health_component.damage(damage)
		if found_hitscal_col:
			create_spark(hitscan_col_point, hitscan_col_normal)
	impacted.emit(true, global_position)
	destroyed.emit()
	call_deferred("queue_free")
