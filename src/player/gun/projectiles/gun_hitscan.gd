extends BaseProjectile
class_name GunHitscan

## Only affect visual
@export var thickness = 10
@export var fade_speed = 2.0

@onready var shot_flash_start = $ShotFlashStart
@onready var raycast: RayCast3D = $RayCast3D
@onready var life_timer: Timer = $Timer
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var nearby_enemy_check_area: Area3D = $NearbyEnemyCheckArea3D

var alpha = 1.0
var end_pos

const DELAY_BETWEEN_RICO = 0.05
const RICO_START_POS_OFFSET_MODIFIER = 0.01
const HITSCAN_HOMING_STRENTH_MODIFIER = 2
const BEAM_RANGE_IF_NOT_COLLIDE = 50

func _ready():
	super ()
	is_hitscan = true
	var dup_mat = mesh.mesh.material.duplicate()
	mesh.mesh.material = dup_mat
	if shot_flash_start:
		var rotate_amount = randi_range(0, 90)
		shot_flash_start.rotate_z(rotate_amount)
		shot_flash_start.modulate = mesh.mesh.material.get_shader_parameter("color")

func _process(delta):
	super (delta)
	alpha -= delta * fade_speed
	alpha = clamp(alpha, 0, 1)
	mesh.mesh.material.set_shader_parameter("fade_multiplier", alpha)
	if shot_flash_start:
		shot_flash_start.modulate.a = clamp(alpha, 0, 1)


func init(start_pos: Vector3, dir: Vector3, _damage: int, ricochet_count: int, _speed: float, _max_range: float):
	visible = false
	global_position = start_pos

	# For homing stuff
	if homing_strength > 0:
		await get_tree().physics_frame
		await get_tree().physics_frame
		var min_distance = 999999
		var test_dist = 0
		var test_dir = 0
		for body in nearby_enemy_check_area.get_overlapping_bodies():
			var target_pos = body.global_position
			if body.get_node("BodyCenter"):
				target_pos = body.get_node("BodyCenter").global_position
			test_dist = start_pos.distance_to(target_pos)
			test_dir = start_pos.direction_to(target_pos)
			var deg_diff = angle_between_vectors(dir, test_dir)
			if test_dist < min_distance and deg_diff < homing_strength * HITSCAN_HOMING_STRENTH_MODIFIER:
				homing_target = body
				min_distance = test_dist
		if homing_target:
			current_dir = test_dir
		else:
			current_dir = dir
	else:
		current_dir = dir

	# Normal hitscan start here
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
		impacted.emit(self, true, hitscan_col_point)
		var calculated_damage = calculate_bullet_damage()
		if target is CharacterBody3D:
			before_damage_applied.emit(target, self)
			target.health_component.damage(calculated_damage)
			damage_applied.emit(calculated_damage, true, target.global_position)
			create_blood_splatter(hitscan_col_point, hitscan_col_normal)
		else:
			if "health_component" in target:
				if target is Shield:
					target.impact(self.global_position)
				elif target is BarrelEffectTrigger:
					target.hit_with_effect(self.owner_gun.installed_barrels)
				target.health_component.damage(damage)
				damage_applied.emit(damage, true, global_position)
			elif target is BartenderBottle:
				target.call_deferred("queue_free")
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

func get_projectile_color() -> Color:
	return mesh.mesh.material.get_shader_parameter("color")

func _on_timer_timeout():
	destroyed.emit()
	queue_free()


func angle_between_vectors(vec1: Vector3, vec2: Vector3) -> float:
	# Normalize the vectors
	var vec1_normalized = vec1.normalized()
	var vec2_normalized = vec2.normalized()
	# Calculate the dot product
	var dot_product = vec1_normalized.dot(vec2_normalized)
	# Clamp the dot product to avoid floating-point errors (to keep it between -1 and 1)
	dot_product = clamp(dot_product, -1.0, 1.0)
	# Calculate the angle in radians
	var angle_radians = acos(dot_product)
	# Convert the angle to degrees
	return rad_to_deg(angle_radians)


func split(split_count: int, split_spread_radius: float, _has_pos: bool, _pos: Vector3):
	if splitted:
		return

	var center_dir = - current_dir
	var new_pos = global_position
	if found_hitscal_col:
		center_dir = hitscan_col_normal
	if _has_pos:
		new_pos = _pos

	for i in range(split_count):
		if not is_instance_valid(self):
			return
		var new_inst = create_duplication()
		get_tree().get_root().add_child(new_inst)
		var new_dir = GunUtils.get_spread_direction(center_dir, split_spread_radius)
		# Offset a bit to prevent stuck inside collision body
		new_pos = hitscan_col_point - current_dir * 0.01
		new_inst.init(new_pos, new_dir, int(damage / split_count), ricochet_count_left, projectile_speed, max_range)
		new_inst.splitted = true


func change_bullet_color(_new_color: Color):
	super (_new_color)
	if color_changed_count > 1:
		var current_mesh_color = mesh.mesh.material.get_shader_parameter("color")
		var current_emission_color = mesh.mesh.material.get_shader_parameter("emission_color")
		mesh.mesh.material.set_shader_parameter("color", current_mesh_color.lerp(_new_color, 0.5))
		mesh.mesh.material.set_shader_parameter("emission_color", current_emission_color.lerp(_new_color, 0.5))
	else:
		mesh.mesh.material.set_shader_parameter("color", _new_color)
		mesh.mesh.material.set_shader_parameter("emission_color", Color(_new_color.r, _new_color.g, _new_color.b, 0.7))
