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
@onready var area_col: CollisionShape3D = $NearbyEnemyCheckArea3D/CollisionShape3D

@onready var ricochet_sfx: AudioStreamPlayer3D = $Ricochet3dAudio

var alpha = 1.0
var end_pos

const DELAY_BETWEEN_RICO = 0.05
const RICO_START_POS_OFFSET_MODIFIER = 0.01
const HITSCAN_HOMING_STRENTH_MODIFIER = 4
const BEAM_RANGE_IF_NOT_COLLIDE = 50


func _ready():
	super ()
	is_hitscan = true
	var dup_mat = mesh.mesh.material.duplicate()
	mesh.mesh.material = dup_mat

func _activate_visuals() -> void:
	self.visible = true
	alpha = 1.0
	mesh.mesh.material.set_shader_parameter("fade_multiplier", 1.0)

func _activate_physics() -> void:
	self.process_mode = Node.PROCESS_MODE_INHERIT
	set_physics_process(true)

	misc_data = {}
	time_ricochetted = 0
	is_ricochet_shot = false
	splitted = false
	
	raycast.set_deferred("enabled", true)
	area_col.set_deferred("disabled", false)
	nearby_enemy_check_area.set_deferred("monitoring", true)
	nearby_enemy_check_area.set_deferred("monitorable", true)


func _deactivate_visuals() -> void:
	self.visible = false
	mesh.mesh.material.set_shader_parameter("fade_multiplier", 0.0)

func _deactivate_physics() -> void:
	life_timer.stop()
	
	splitted = false
	is_ricochet_shot = false
	
	raycast.set_deferred("enabled", false)
	area_col.set_deferred("disabled", true)
	nearby_enemy_check_area.set_deferred("monitoring", false)
	nearby_enemy_check_area.set_deferred("monitorable", false)
	
	self.process_mode = Node.PROCESS_MODE_DISABLED
	set_physics_process(false)


func _process(delta):
	super (delta)
	alpha -= delta * fade_speed
	alpha = clamp(alpha, 0, 1)
	mesh.mesh.material.set_shader_parameter("fade_multiplier", alpha)
	if shot_flash_start:
		shot_flash_start.modulate.a = clamp(alpha, 0, 1)


func init(start_pos: Vector3, dir: Vector3, _damage: int, ricochet_count: int, _speed: float, _max_range: float):
	activate()

	if shot_flash_start:
		var rotate_amount = randi_range(0, 90)
		shot_flash_start.rotate_z(rotate_amount)
		shot_flash_start.modulate = mesh.mesh.material.get_shader_parameter("color")
	
	self.visible = false
	self.global_position = start_pos
	
	# For homing stuff, it will overwrite player aim and autotarget enemy body center
	# nearest the crosshair
	if homing_strength > 0:
		await get_tree().physics_frame
		await get_tree().physics_frame
		
		var min_distance = 999999
		var test_dist = 0
		var homing_enemy_dir = 0
		
		# Find the enemy body to overwrite
		for body in nearby_enemy_check_area.get_overlapping_bodies():
			var target_pos = body.global_position
			if body.has_node("BodyCenter"):
				target_pos = body.get_node("BodyCenter").global_position
			
			test_dist = start_pos.distance_to(target_pos)
			homing_enemy_dir = start_pos.direction_to(target_pos)
			var deg_diff = GunUtils.angle_between_vectors(dir, homing_enemy_dir)
			if test_dist < min_distance and deg_diff < homing_strength * HITSCAN_HOMING_STRENTH_MODIFIER:
				homing_target = body
				min_distance = test_dist
		
		if homing_target:
			current_dir = homing_enemy_dir
		else:
			current_dir = dir
	else:
		current_dir = dir
	
	# Normal hitscan start here
	life_timer.start()
	damage = _damage
	if GameManager.player:
		crit_chance = GameManager.player.current_stats[StatusEffect.PlayerStatEnum.CRITICAL_HIT_CHANCE]
	else:
		crit_chance = GameManager.player_base_stats[StatusEffect.PlayerStatEnum.CRITICAL_HIT_CHANCE]
	
	projectile_speed = _speed
	ricochet_count_left = ricochet_count
	max_range = _max_range
	raycast.target_position.z = - abs(_max_range)
	
	look_at_from_position(start_pos, start_pos + current_dir * _max_range, Vector3.UP)
	
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
			self.position += current_dir * (distance_to_hit_pos / 2.0)
			mesh.scale = Vector3(0.01 * thickness, 0.01 * thickness, distance_to_hit_pos)
			if is_ricochet_shot:
				mesh.mesh.material.set_shader_parameter("enable_fade", false)
				mesh.mesh.material.set_shader_parameter("enable_taper", false)
			else:
				mesh.mesh.material.set_shader_parameter("enable_fade", true)
				mesh.mesh.material.set_shader_parameter("enable_taper", true)
				mesh.mesh.material.set_shader_parameter("fade_distance", distance_to_hit_pos / 4)
				mesh.mesh.material.set_shader_parameter("origin_position", start_pos)
			
			self.visible = true
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
	self.position += current_dir * (distance / 2.0)
	mesh.scale = Vector3(0.01 * thickness, 0.01 * thickness, distance)
	# Reset base color
	mesh.mesh.material.set_shader_parameter("color", Color("#ff9106"))
	mesh.mesh.material.set_shader_parameter("emission_color", Color("#ffc600"))
	
	if is_ricochet_shot:
		redshift_bullet()
		mesh.mesh.material.set_shader_parameter("enable_fade", false)
		mesh.mesh.material.set_shader_parameter("enable_taper", false)
	else:
		mesh.mesh.material.set_shader_parameter("enable_fade", true)
		mesh.mesh.material.set_shader_parameter("enable_taper", true)
		mesh.mesh.material.set_shader_parameter("fade_distance", distance / 4)
		mesh.mesh.material.set_shader_parameter("origin_position", start_pos)
	
	self.visible = true
	mesh.mesh.material.set_shader_parameter("fade_multiplier", 1.0)

	if splitted:
		redshift_bullet()


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
	play_ricochet_sfx()
	# 
	var new_inst: GunHitscan = create_duplication(true) # Also set is_ricochet
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
	destroyed.emit(self , hit_boss)
	finished.emit.call_deferred()


func split(split_count: int, split_spread_radius: float, has_pos: bool, _pos: Vector3):
	var pos_hitscan: Vector3 = hitscan_col_point - current_dir * 0.01
	super (split_count, split_spread_radius, has_pos, pos_hitscan)


func redshift_bullet():
	var current_color = mesh.mesh.material.get_shader_parameter("color")
	var redshifted_color = Color(
		current_color.r + (1.0 - current_color.r) * 0.5, # Shift red towards 1.0
		current_color.g * 0.7, # Reduce green
		current_color.b * 0.3, # Reduce blue significantly
		current_color.a
	)
	change_bullet_color(redshifted_color)


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
