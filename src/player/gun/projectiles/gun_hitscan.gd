extends BaseProjectile
class_name GunHitscan

## Only affect visual
@export var thickness = 1

@onready var shot_flash_start = $ShotFlashStart
@onready var raycast: RayCast3D = $RayCast3D

signal damage_applied
signal impacted
signal destroyed

var damage = 1
var alpha = 1.0
var fade_speed = 4.0
var found_hitscal_col = false
var hitscan_col_point = Vector3.ZERO
var hitscan_col_normal = Vector3.ZERO
var end_pos

func _ready():
	var dup_mat = material_override.duplicate()
	material_override = dup_mat
	if shot_flash_start:
		var rotate_amount = randi_range(0, 90)
		shot_flash_start.rotate_z(rotate_amount)
		shot_flash_start.modulate = material_override.get_shader_parameter("color")

func init(start_pos: Vector3, dir: Vector3, _damage: int, max_range: float):
	damage = _damage
	raycast.target_position.z = -abs(max_range)
	self.look_at_from_position(start_pos, start_pos + dir, Vector3.UP)

	await get_tree().physics_frame
	await get_tree().physics_frame

	if raycast.is_colliding():
		impacted.emit()
		var target = raycast.get_collider()
		hitscan_col_point = raycast.get_collision_point()
		hitscan_col_normal = raycast.get_collision_normal()
		end_pos = hitscan_col_point
		if target is CharacterBody3D:
			target.health_component.damage(damage)
			damage_applied.emit()
			create_blood_splatter(hitscan_col_point, hitscan_col_normal)
		else:
			create_spark(hitscan_col_point, hitscan_col_normal)

	else:
		end_pos = start_pos + dir * max_range

	var distance = start_pos.distance_to(end_pos)
	self.scale = Vector3(0.01 * thickness, 0.01 * thickness, distance)
	material_override.set_shader_parameter("fade_distance", distance / 4)
	material_override.set_shader_parameter("origin_position", start_pos)


func _process(delta):
	alpha -= delta * fade_speed
	alpha = clamp(alpha, 0, 1)
	material_override.set_shader_parameter("fade_multiplier", alpha)
	if shot_flash_start:
		shot_flash_start.modulate.a = clamp(alpha, 0, 1)

func get_projectile_color() -> Color:
	return material_override.get_shader_parameter("color")

func _on_timer_timeout():
	destroyed.emit()
	queue_free()
