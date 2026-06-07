extends BaseBullet
class_name GunProjectile

@export var gravity_modifier = 0.0

@onready var raycast: RayCast3D = $RayCast3D
@onready var life_timer: Timer = $LifeTimer
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var area: Area3D = $Area3D
@onready var area_col: CollisionShape3D = $Area3D/CollisionShape3D
@onready var trail: Trail3D = $Trail/Trail3D
@onready var slowmo_trail: Trail3D = $Trail/Trail3DBulletTime

@onready var ricochet_sfx: AudioStreamPlayer3D = $Ricochet3dAudio


# Gravity stuff
const MAX_GRAVITY_PITCH = deg_to_rad(90.0)
const ROTATE_RATE_MODIFIER = 0.25
const GRAVITY_IGNORE_AFTER_RICO_TIME = 0.2

var gravity_accel = 0
var gravity_free_timer = 0.2


func _activate_visuals() -> void:
	self.visible = true
	trail.visible = true
	trail.emit = true

func _deactivate_visuals() -> void:
	self.visible = false
	trail.visible = false
	trail.emit = false
	slowmo_trail.visible = false

func _activate_physics() -> void:
	self.process_mode = Node.PROCESS_MODE_INHERIT
	trail.process_mode = Node.PROCESS_MODE_INHERIT
	slowmo_trail.process_mode = Node.PROCESS_MODE_INHERIT
	set_physics_process(true)

	life_timer.start()

	raycast.set_deferred("enabled", true)
	raycast.call_deferred("force_raycast_update")
	area_col.set_deferred("disabled", false)
	area.set_deferred("monitoring", true)
	area.set_deferred("monitorable", true)
	

func _deactivate_physics() -> void:
	splitted = false
	is_ricochet_shot = false
	
	trail.full_reset()
	life_timer.stop()
	
	raycast.set_deferred("enabled", false)
	area_col.set_deferred("disabled", true)
	area.set_deferred("monitoring", false)
	area.set_deferred("monitorable", false)

	slowmo_trail.process_mode = Node.PROCESS_MODE_DISABLED
	trail.process_mode = Node.PROCESS_MODE_DISABLED
	self.process_mode = Node.PROCESS_MODE_DISABLED
	set_physics_process(false)


func _process(delta: float) -> void:
	super (delta)
	gravity_free_timer += delta

func _physics_process(delta: float) -> void:
	if homing_strength > 0 and GameManager.player and is_instance_valid(GameManager.player.last_look_enemy_target):
		var target = GameManager.player.last_look_enemy_target
		var target_pos = target.global_position
		if target.has_node("BodyCenter"):
			target_pos = target.get_node("BodyCenter").global_position
		var dist_to_target = global_position.distance_to(target_pos)
		var homing_range = homing_strength * HOMING_RANGE_FACTOR
		if dist_to_target <= homing_range:
			var current_dir_vec = - transform.basis.z
			var dir_to_target = global_position.direction_to(target_pos)
			var new_dir = current_dir_vec.lerp(dir_to_target, homing_strength * HOMING_STRENGTH_FACTOR).normalized()
			homing_curved_degrees += rad_to_deg(current_dir_vec.angle_to(new_dir))
			look_at(global_position + new_dir)
	elif can_be_aim_guided and life_time >= min_lifetime_before_can_be_aim_guided:
		var aiming_position = GunUtils.get_player_aiming_position()
		var dir_to_target = global_position.direction_to(aiming_position)
		look_at(global_position + dir_to_target)

	velocity = - transform.basis.z * projectile_speed * delta
	global_position += velocity
	travelled_distance += projectile_speed * delta


	if gravity_modifier > 0 and gravity_free_timer > GRAVITY_IGNORE_AFTER_RICO_TIME:
		gravity_accel += GRAVITY_FORCE * gravity_modifier * delta
		global_position += Vector3(0, 1, 0) * gravity_accel * delta
		# Pitch downward based on accumulated gravity
		var pitch_angle = gravity_accel * ROTATE_RATE_MODIFIER * delta # radians per frame
		var dot = - raycast.global_transform.basis.z.dot(Vector3.DOWN)
		# If dot > 0.99, it point almost downward. Downward == 1
		# Only rotate if not point downward
		if dot < 0.99:
			raycast.rotate_object_local(Vector3(1, 0, 0), pitch_angle)

func init(start_pos: Vector3, dir: Vector3, _damage: int, ricochet_count: int, _speed: float, _max_range: float):
	look_at_from_position(start_pos, start_pos + dir)
	activate()
	
	life_timer.start()
	projectile_speed = _speed
	max_range = _max_range
	damage = _damage
	if GameManager.player:
		crit_chance = GameManager.player.current_stats[StatusEffect.PlayerStatEnum.CRITICAL_HIT_CHANCE]
	else:
		crit_chance = GameManager.player_base_stats[StatusEffect.PlayerStatEnum.CRITICAL_HIT_CHANCE]
	
	current_dir = dir
	ricochet_count_left = ricochet_count

	await get_tree().process_frame
	await get_tree().process_frame
	
	check_raycast_col()

	if splitted:
		redshift_bullet()


func _on_life_timer_timeout() -> void:
	destroyed.emit(self, hit_boss)
	finished.emit.call_deferred()

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
	gravity_free_timer = 0
	found_hitscal_col = false
	# Redshift the bullet color after ricochet. Only do it once.
	if is_ricochet_shot == false:
		redshift_bullet()
		is_ricochet_shot = true
		
	play_ricochet_sfx()
	
	# Calculate bounce direction
	var bounce_dir = current_dir.bounce(hitscan_col_normal)
	
	# Add slight homing toward last look enemy target if available
	if GameManager.player and is_instance_valid(GameManager.player.last_look_enemy_target):
		var target = GameManager.player.last_look_enemy_target
		var dir_to_target = global_position.direction_to(target.global_position)
		# Blend bounce direction with target direction (small homing factor)
		bounce_dir = bounce_dir.lerp(dir_to_target, RICOCHET_HOMING_STRENGTH).normalized()
	
	init(global_position, bounce_dir, damage, ricochet_count_left - 1, projectile_speed, max_range)
	raycast.rotation = Vector3.ZERO
	gravity_accel = 0


func split(split_count: int, split_spread_radius: float, has_pos: bool, pos: Vector3):
	super (split_count, split_spread_radius, has_pos, pos)
	# Maybe play a split SFX here


func _on_area_3d_body_entered(body: Node3D) -> void:
	if not is_instance_valid(owner_gun):
		return
	
	if body is Player:
		on_player_contact.emit(self )
		if time_ricochetted == 0:
			return

	check_raycast_col()
	
	var calculated_damage = calculate_bullet_damage()
	
	if body is CharacterBody3D:
		if is_instance_valid(body):
			before_damage_applied.emit(body, self )
			#calculated_damage = calculate_bullet_damage(false) # Recalculate damage after before_damage_applied effect
			apply_damage_to_health_component(body.health_component, calculated_damage)
			damage_applied.emit(calculated_damage, true, global_position)
			ricochet_count_left = 0
			hit_boss = true
		if found_hitscal_col:
			create_blood_splatter(hitscan_col_point, hitscan_col_normal)
		else:
			create_blood_splatter(global_position, Vector3.UP)
	else:
		if "health_component" in body:
			if body is Shield:
				body.impact(self.global_position)
			elif body is BarrelEffectTrigger or body is SingleEffectTrigger:
				body.hit_with_effect(self.owner_gun.installed_barrels)
			apply_damage_to_health_component(body.health_component, calculated_damage)
			damage_applied.emit(calculated_damage, true, global_position)
			hit_boss = true
		if found_hitscal_col and gravity_accel == 0:
			call_deferred("create_spark", hitscan_col_point, hitscan_col_normal)
			call_deferred("create_bullet_decal", hitscan_col_point, hitscan_col_normal)
		else:
			call_deferred("create_spark", global_position, Vector3.UP)
			call_deferred("create_bullet_decal", global_position, Vector3.UP)
	impacted.emit(self , true, global_position)

	if ricochet_count_left > 0 and found_hitscal_col:
		ricochet()
	else:
		destroyed.emit(self, hit_boss)
		finished.emit.call_deferred()


func check_raycast_col():
	if raycast.is_colliding():
		hitscan_col_point = raycast.get_collision_point()
		hitscan_col_normal = raycast.get_collision_normal()
		found_hitscal_col = true
	else:
		found_hitscal_col = false

func change_bullet_color(_new_color: Color):
	super (_new_color)
	if color_changed_count > 1:
		mesh.mesh.material.albedo_color = mesh.mesh.material.albedo_color.lerp(_new_color, 0.5)
		mesh.mesh.material.emission = mesh.mesh.material.emission.lerp(_new_color, 0.5)
		trail.material_override.albedo_color = trail.material_override.albedo_color.lerp(_new_color, 0.5)
		trail.material_override.emission = trail.material_override.emission.lerp(_new_color, 0.5)
	else:
		mesh.mesh.material.albedo_color = _new_color
		mesh.mesh.material.emission = _new_color
		trail.material_override.albedo_color = Color(_new_color.r, _new_color.g, _new_color.b, 0.7)
		trail.material_override.emission = _new_color


func redshift_bullet():
	var current_color = mesh.mesh.material.albedo_color
	var redshifted_color = Color(
		current_color.r + (1.0 - current_color.r) * 0.5, # Shift red towards 1.0
		current_color.g * 0.7, # Reduce green
		current_color.b * 0.3, # Reduce blue significantly
		current_color.a
	)
	change_bullet_color(redshifted_color)


func switch_to_slowmo_bullet_trail():
	super ()
	# Better optimization is instantiate and add the slowmo later?
	trail.visible = false
	trail.clear_points()
	trail.process_mode = Node.PROCESS_MODE_DISABLED
	slowmo_trail.visible = true
	slowmo_trail.process_mode = Node.PROCESS_MODE_INHERIT
