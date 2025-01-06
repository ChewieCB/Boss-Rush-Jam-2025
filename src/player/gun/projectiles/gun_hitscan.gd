extends BaseProjectile
class_name GunHitscan

## Only affect visual
@export var thickness = 1

@onready var shot_flash_start = $ShotFlashStart

var alpha = 1.0
var fade_speed = 4.0

func _ready():
	var dup_mat = material_override.duplicate()
	material_override = dup_mat
	if shot_flash_start:
		var rotate_amount = randi_range(0, 90)
		shot_flash_start.rotate_z(rotate_amount)
		shot_flash_start.modulate = material_override.albedo_color

func init(pos1: Vector3, pos2: Vector3, _fade_speed: float = 4.0):
	fade_speed = _fade_speed
	self.scale = Vector3(0.01 * thickness, 0.01 * thickness, pos1.distance_to(pos2))
	self.look_at_from_position((pos1 + pos2) / 2, pos2, Vector3.UP)

func _process(delta):
	alpha -= delta * fade_speed
	alpha = clamp(alpha, 0, 1)
	material_override.albedo_color.a = alpha
	if shot_flash_start:
		shot_flash_start.modulate.a = clamp(alpha, 0, 1)

func get_projectile_color() -> Color:
	return material_override.albedo_color

func _on_timer_timeout():
	queue_free()
