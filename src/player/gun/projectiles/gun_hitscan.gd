extends BaseProjectile
class_name GunHitscan

## Only affect visual
@export var thickness = 1

@onready var shot_flash_start = $ShotFlashStart
@onready var raycast: RayCast3D = $RayCast3D
@onready var life_timer: Timer = $Timer

var alpha = 1.0
var fade_speed = 4.0
var found_hitscal_col = false
var hitscan_col_point = Vector3.ZERO
var hitscan_col_normal = Vector3.ZERO
var end_pos
var current_dir
var max_range

const DELAY_BETWEEN_RICO = 0.05
const RICO_START_POS_OFFSET_MODIFIER = 0.01

func _ready():
	var dup_mat = material_override.duplicate()
	material_override = dup_mat
	if shot_flash_start:
		var rotate_amount = randi_range(0, 90)
		shot_flash_start.rotate_z(rotate_amount)
		shot_flash_start.modulate = material_override.get_shader_parameter("color")

func _process(delta):
	alpha -= delta * fade_speed
	alpha = clamp(alpha, 0, 1)
	material_override.set_shader_parameter("fade_multiplier", alpha)
	if shot_flash_start:
		shot_flash_start.modulate.a = clamp(alpha, 0, 1)


func init(start_pos: Vector3, dir: Vector3, _damage: int, ricochet_count: int, _max_range: float):
	visible = false
	life_timer.start()
	current_dir = dir
	damage = _damage
	ricochet_count_left = ricochet_count
	max_range = _max_range
	raycast.target_position.z = -abs(_max_range)
	self.look_at_from_position(start_pos, start_pos + dir * _max_range, Vector3.UP)

	await get_tree().physics_frame
	await get_tree().physics_frame

	if raycast.is_colliding():
		found_hitscal_col = true
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
		if ricochet_count_left > 0:
			ricochet()
	else:
		end_pos = start_pos + dir * max_range

	var distance = start_pos.distance_to(end_pos)
	position += current_dir * (distance / 2.0)
	self.scale = Vector3(0.01 * thickness, 0.01 * thickness, distance)
	if is_ricochet_shot:
		material_override.set_shader_parameter("enable_fade", false)
		material_override.set_shader_parameter("enable_taper", false)
	else:
		material_override.set_shader_parameter("enable_fade", true)
		material_override.set_shader_parameter("enable_taper", true)
		material_override.set_shader_parameter("fade_distance", distance / 4)
		material_override.set_shader_parameter("origin_position", start_pos)
	visible = true


func ricochet():
	super()
	await get_tree().create_timer(DELAY_BETWEEN_RICO).timeout
	found_hitscal_col = false
	var new_hitscan_inst: GunHitscan = self.duplicate()
	GameManager.player.get_parent().add_child(new_hitscan_inst)
	new_hitscan_inst.owner_gun = owner_gun
	new_hitscan_inst.is_ricochet_shot = true
	var new_dir = current_dir.bounce(hitscan_col_normal)
	# Offset a bit to prevent stuck inside collision body
	var new_start_pos = hitscan_col_point - current_dir * RICO_START_POS_OFFSET_MODIFIER
	new_hitscan_inst.init(new_start_pos, new_dir, damage, ricochet_count_left - 1, max_range)
	new_hitscan_inst.damage_applied.connect(owner_gun.check_barrel_effect_on_damage_applied)
	new_hitscan_inst.impacted.connect(owner_gun.check_barrel_effect_on_projectile_impact)
	new_hitscan_inst.destroyed.connect(owner_gun.check_barrel_effect_on_projectile_destroyed)


func get_projectile_color() -> Color:
	return material_override.get_shader_parameter("color")

func _on_timer_timeout():
	destroyed.emit()
	queue_free()
