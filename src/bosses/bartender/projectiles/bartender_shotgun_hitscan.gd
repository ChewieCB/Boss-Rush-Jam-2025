extends BaseBullet
class_name BartenderShotgunHitscan

## Only affect visual
@export var thickness = 10
@export var fade_speed = 2.0

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var raycast: RayCast3D = $RayCast3D
@onready var life_timer: Timer = $LifeTimer

var alpha = 1.0
var end_pos

const DELAY_BETWEEN_RICO = 0.05
const RICO_START_POS_OFFSET_MODIFIER = 0.01
const BEAM_RANGE_IF_NOT_COLLIDE = 50

func _ready():
	super ()
	is_hitscan = true
	var dup_mat = mesh.mesh.material.duplicate()
	mesh.mesh.material = dup_mat

func _process(delta):
	super (delta)
	alpha -= delta * fade_speed
	alpha = clamp(alpha, 0, 1)
	mesh.mesh.material.set_shader_parameter("fade_multiplier", alpha)


func init(start_pos: Vector3, dir: Vector3, _damage: int, ricochet_count: int, _speed: float, _max_range: float):
	visible = false
	global_position = start_pos
	current_dir = dir

	life_timer.start()
	damage = _damage
	projectile_speed = _speed
	ricochet_count_left = ricochet_count
	max_range = _max_range
	raycast.target_position.z = - abs(_max_range)
	self.look_at_from_position(start_pos, start_pos + current_dir * _max_range, Vector3.UP)

	await get_tree().physics_frame
	await get_tree().physics_frame

	if raycast.is_colliding():
		found_hitscal_col = true
		var target = raycast.get_collider()
		hitscan_col_point = raycast.get_collision_point()
		hitscan_col_normal = raycast.get_collision_normal()
		end_pos = hitscan_col_point
		travelled_distance += start_pos.distance_to(end_pos)

		impacted.emit(self , true, hitscan_col_point)
		if target is CharacterBody3D:
			target.health_component.damage(damage)
			create_blood_splatter(hitscan_col_point, hitscan_col_normal)
		else:
			if "health_component" in target:
				if target is Shield:
					target.impact(self.global_position)
				target.health_component.damage(damage)
			create_spark(hitscan_col_point, hitscan_col_normal)
			create_bullet_decal(hitscan_col_point, hitscan_col_normal)
		if ricochet_count_left > 0:
			ricochet()
	else:
		end_pos = start_pos + current_dir * BEAM_RANGE_IF_NOT_COLLIDE

	var distance = start_pos.distance_to(end_pos)
	position += current_dir * (distance / 2.0)
	mesh.scale = Vector3(0.01 * thickness, 0.01 * thickness, distance)
	if is_ricochet_shot:
		mesh.mesh.material.set_shader_parameter("enable_fade", false)
		mesh.mesh.material.set_shader_parameter("enable_taper", false)
	else:
		mesh.mesh.material.set_shader_parameter("enable_fade", true)
		mesh.mesh.material.set_shader_parameter("enable_taper", true)
		mesh.mesh.material.set_shader_parameter("fade_distance", distance / 4)
		mesh.mesh.material.set_shader_parameter("origin_position", start_pos)
	visible = true


func ricochet():
	super ()
	await get_tree().create_timer(DELAY_BETWEEN_RICO).timeout
	found_hitscal_col = false
	var new_hitscan_inst: GunHitscan = create_duplication()
	get_tree().get_root().add_child(new_hitscan_inst)
	var new_dir = current_dir.bounce(hitscan_col_normal)
	# Offset a bit to prevent stuck inside collision body
	var new_start_pos = hitscan_col_point - current_dir * RICO_START_POS_OFFSET_MODIFIER
	new_hitscan_inst.init(new_start_pos, new_dir, damage, ricochet_count_left - 1, projectile_speed, max_range)


func _on_life_timer_timeout() -> void:
	queue_free()
