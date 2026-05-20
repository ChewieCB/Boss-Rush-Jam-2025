extends BaseBullet
class_name GunHitscan

signal end_pos_set(pos: Vector3)

## Only affect visual
@export var thickness = 10
@export var fade_speed = 2.0

@onready var shot_flash_start = $ShotFlashStart
@onready var raycast: RayCast3D = $RayCast3D
@onready var life_timer: Timer = $Timer
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var nearby_enemy_check_area: Area3D = $NearbyEnemyCheckArea3D

@onready var ricochet_sfx: AudioStreamPlayer3D = $Ricochet3dAudio

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
	# if is_ricochet_shot:
	# 	redshift_bullet()

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
			var deg_diff = GunUtils.angle_between_vectors(dir, test_dir)
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

		if target is BlockingDetectionArea:
			var buffered_hit_pos: Vector3 = target._raycast_hit(self , end_pos)
			end_pos_set.emit(buffered_hit_pos)
			create_spark(buffered_hit_pos, hitscan_col_normal)

			var distance_to_hit_pos = start_pos.distance_to(buffered_hit_pos)
			position += current_dir * (distance_to_hit_pos / 2.0)
			mesh.scale = Vector3(0.01 * thickness, 0.01 * thickness, distance_to_hit_pos)
			if is_ricochet_shot:
				mesh.mesh.material.set_shader_parameter("enable_fade", false)
				mesh.mesh.material.set_shader_parameter("enable_taper", false)
			else:
				mesh.mesh.material.set_shader_parameter("enable_fade", true)
				mesh.mesh.material.set_shader_parameter("enable_taper", true)
				mesh.mesh.material.set_shader_parameter("fade_distance", distance_to_hit_pos / 4)
				mesh.mesh.material.set_shader_parameter("origin_position", start_pos)
			visible = true
			return

		impacted.emit(self , true, hitscan_col_point)
		var calculated_damage = calculate_bullet_damage()
		
		if target is ChiptopedeSegmentCollision:
			# Pass any damage on to the actual boss
			target = target.parent
		
		if target is CharacterBody3D:
			before_damage_applied.emit(target, self )
			calculated_damage = calculate_bullet_damage(false) # Recalculate damage after before_damage_applied effect
			apply_damage_to_health_component(target.health_component, calculated_damage)
			damage_applied.emit(calculated_damage, true, target.global_position)
			hit_boss = true
			call_deferred("create_blood_splatter", hitscan_col_point, hitscan_col_normal)
		else:
			if "health_component" in target:
				if target is Shield:
					target.impact(self.global_position)
				elif target is BarrelEffectTrigger or target is SingleEffectTrigger:
					target.hit_with_effect(self.owner_gun.installed_barrels)
				apply_damage_to_health_component(target.health_component, calculated_damage)
				damage_applied.emit(calculated_damage, true, global_position)
				hit_boss = true
			elif target is BartenderBottle:
				target.call_deferred("queue_free")
			call_deferred("create_spark", hitscan_col_point, hitscan_col_normal)
			call_deferred("create_bullet_decal", hitscan_col_point, hitscan_col_normal)
		if ricochet_count_left > 0:
			ricochet()
	else:
		end_pos = start_pos + current_dir * BEAM_RANGE_IF_NOT_COLLIDE

	end_pos_set.emit(end_pos)

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

func play_ricochet_sfx():
	var sfx = AudioStreamPlayer3D.new()
	sfx.stream = ricochet_sfx.stream
	sfx.stream = ricochet_sfx.stream
	sfx.unit_size = ricochet_sfx.unit_size
	sfx.max_distance = ricochet_sfx.max_distance
	sfx.volume_db = ricochet_sfx.volume_db
	sfx.attenuation_model = ricochet_sfx.attenuation_model
	get_tree().root.add_child(sfx)
	sfx.global_position = global_position
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

func ricochet():
	super ()
	raycast.set_collision_mask_value(2, true) # Dmg player
	await get_tree().create_timer(DELAY_BETWEEN_RICO).timeout
	found_hitscal_col = false
	print("test")
	play_ricochet_sfx()
	var new_inst: GunHitscan = create_duplication(true) # Also set is_ricochet
	get_tree().get_root().add_child(new_inst)
	new_inst.mesh.mesh.material = mesh.mesh.material.duplicate()
	var new_dir = current_dir.bounce(hitscan_col_normal)
	
	
	# Add slight homing toward last look enemy target if available
	if GameManager.player and is_instance_valid(GameManager.player.last_look_enemy_target):
		var target = GameManager.player.last_look_enemy_target
		var dir_to_target = global_position.direction_to(target.global_position)
		# Blend bounce direction with target direction (small homing factor). Bonus for hitscan because i like it
		new_dir = new_dir.lerp(dir_to_target, RICOCHET_HOMING_STRENGTH).normalized()
	
	# Offset a bit to prevent stuck inside collision body
	var new_start_pos = hitscan_col_point - new_dir * RICO_START_POS_OFFSET_MODIFIER
	new_inst.init(new_start_pos, new_dir, damage, ricochet_count_left - 1, projectile_speed, max_range)
	# Redshift the bullet color after ricochet. Only do it once.
		
func get_projectile_color() -> Color:
	return mesh.mesh.material.get_shader_parameter("color")

func _on_timer_timeout():
	destroyed.emit(hit_boss)
	queue_free()

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
		if not is_instance_valid(self ):
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


# func redshift_bullet():
# 	var current_color = mesh.mesh.material.get_shader_parameter("emission_color")
# 	var redshifted_color = Color(
# 		current_color.r + (1.0 - current_color.r) * 0.5, # Shift red towards 1.0
# 		current_color.g * 0.7, # Reduce green
# 		current_color.b * 0.3, # Reduce blue significantly
# 		current_color.a
# 	)
# 	change_bullet_color(redshifted_color)
