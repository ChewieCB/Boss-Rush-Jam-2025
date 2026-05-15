extends BaseBullet
class_name StickyBombProjectile

@export var delay_explosion_time = 3
@export var delay_randomness = 0.22
@export var explosion_prefab: PackedScene
@export var explosion_vfx: PackedScene

@onready var raycast: RayCast3D = $RayCast3D
@onready var life_timer: Timer = $LifeTimer
@onready var explode_timer: Timer = $ExplodeTimer
@onready var homing_area: Area3D = $HomingArea3D
@onready var homing_collision_shape: CollisionShape3D = $HomingArea3D/CollisionShape3D
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var trail: Trail3D = $Trail/Trail3D
@onready var tick_sfx_player: AudioStreamPlayer3D = $TickSFXPlayer

const CONTACT_DAMAGE = 1

var sticked = false
var explosion_damage = 0

func _ready() -> void:
	super()
	randomize()
	delay_explosion_time += randf_range(-delay_randomness, delay_randomness)
	explode_timer.wait_time = delay_explosion_time
	life_timer.wait_time = delay_explosion_time
	mesh.mesh.material = mesh.mesh.material.duplicate(true)

func _process(delta: float) -> void:
	super (delta)

func _physics_process(delta: float) -> void:
	if sticked:
		return

	if homing_locked_in and homing_target:
		var target_pos = homing_target.global_position
		if homing_target.get_node("BodyCenter"):
			target_pos = homing_target.get_node("BodyCenter").global_position
		var dir_to_target = global_position.direction_to(target_pos)
		look_at(global_position + dir_to_target)
	elif can_be_aim_guided and life_time >= min_lifetime_before_can_be_aim_guided:
		var aiming_position = GunUtils.get_player_aiming_position()
		var dir_to_target = global_position.direction_to(aiming_position)
		look_at(global_position + dir_to_target)

	velocity = - transform.basis.z * projectile_speed * delta
	global_position += velocity
	travelled_distance += projectile_speed * delta


func init(start_pos: Vector3, dir: Vector3, _damage: int, ricochet_count: int, _speed: float, _max_range: float):
	if homing_strength > 0:
		homing_area.monitoring = true
		homing_collision_shape.shape.radius = homing_strength
	life_timer.start()
	
	projectile_speed = _speed
	max_range = _max_range
	damage = CONTACT_DAMAGE
	explosion_damage = _damage
	current_dir = dir
	ricochet_count_left = ricochet_count
	look_at_from_position(start_pos, start_pos + dir)

	await get_tree().physics_frame
	await get_tree().physics_frame

	if raycast.is_colliding():
		hitscan_col_point = raycast.get_collision_point()
		hitscan_col_normal = raycast.get_collision_normal()
		found_hitscal_col = true
	
	# We want each tick to get faster
	var ticks: int = 6
	var tick_times: Array[float] = []
	var k: float = 2.5  # Acceleration intensity
	
	for i in range(ticks):
		var x = float(i) / float(ticks - 1)
		var t = (delay_explosion_time) * ((exp(k * x) - 1.0) / (exp(k) - 1.0))
		tick_times.append(t)
	
	var tick_durations: Array[float] = []
	for i in range(ticks - 1):
		tick_durations.append(tick_times[i + 1] - tick_times[i])
	tick_durations.reverse()
	
	tick_sfx_player.volume_db = -6
	var start_colour := Color("#f70000")
	var end_colour := Color("#ba2f20")
	for i in range(tick_durations.size()):
		var duration = tick_durations[i]
		if i == tick_durations.size() - 1:
			await anim_countdown_final_tick(duration, i * 0.55, start_colour.lerp(end_colour, i / tick_durations.size()))
		else:
			await anim_countdown_tick(duration, i * 0.55, start_colour.lerp(end_colour, i / tick_durations.size()))
			tick_sfx_player.volume_db += 4


func ricochet():
	super ()
	found_hitscal_col = false
	is_ricochet_shot = true
	init(global_position, current_dir.bounce(hitscan_col_normal), explosion_damage, ricochet_count_left - 1, projectile_speed, max_range)


func _on_life_timer_timeout() -> void:
	destroyed.emit(false)
	stop_elemental_particles()
	call_deferred("queue_free")

func _on_area_3d_body_entered(body: Node3D) -> void:
	if sticked:
		return
	var calculated_damage = calculate_bullet_damage()
	if body is CharacterBody3D:
		if is_instance_valid(body):
			before_damage_applied.emit(body, self)
			calculated_damage = calculate_bullet_damage(false) # Recalculate damage after before_damage_applied effect
			apply_damage_to_health_component(body.health_component, calculated_damage)
			damage_applied.emit(damage, true, global_position)
			hit_boss = true
	else:
		if body is Shield:
			body.impact(self.global_position)
			apply_damage_to_health_component(body.health_component, calculated_damage)
			hit_boss = true
		elif "health_component" in body:
			apply_damage_to_health_component(body.health_component, calculated_damage)
			hit_boss = true
	self.reparent.call_deferred(body)
	sticked = true
	life_timer.stop()
	explode_timer.start()
	impacted.emit(self, true, global_position)


func _on_homing_area_3d_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		homing_locked_in = true
		homing_target = body
		homing_area.set_deferred("monitoring", false)


func _on_explode_timer_timeout() -> void:
	var inst: ExplosionDamageArea = explosion_prefab.instantiate()
	var calculated_explosion_damage = calculate_explosion_damage()
	inst.init(calculated_explosion_damage)
	get_parent().add_child(inst)
	for i in range(infused_status_effect.size()):
		if infused_status_effect[i]:
			inst.add_status_effect(i + 1)  # Offset for the None enum value
	inst.activate(global_position)

	var vfx = explosion_vfx.instantiate()
	var vfx_color: Color = Color.ORANGE
	var most_recent_status: int = -1
	for i in range(infused_status_effect.size()):
		if infused_status_effect[i]:
			most_recent_status = i + 1
	match most_recent_status:
		BossCore.BossStatusEffect.BURNING:
			vfx_color = Color.TOMATO
		BossCore.BossStatusEffect.POISONED:
			vfx_color = Color.DARK_GREEN
		BossCore.BossStatusEffect.FROZEN:
			vfx_color = Color.AQUA
		BossCore.BossStatusEffect.SHOCKED:
			vfx_color = Color.LIGHT_GOLDENROD
		BossCore.BossStatusEffect.BLEEDING:
			vfx_color = Color.DARK_RED
	get_parent().add_child(vfx)
	vfx.global_position = global_position
	vfx.set_colour(vfx_color)

	if ricochet_count_left > 0 and found_hitscal_col:
		sticked = false
		self.reparent.call_deferred(get_tree().get_root())
		ricochet()
	else:
		await get_tree().create_timer(0.25).timeout
		destroyed.emit(hit_boss)
		stop_elemental_particles()
		call_deferred("queue_free")


func change_bullet_color(_new_color: Color):
	super(_new_color)
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


func calculate_explosion_damage():
	var rand_damage_mod = get_damage_variance_modifier(explosion_damage)
	var calculated_damage = explosion_damage + rand_damage_mod
	# Crit
	var roll = randi_range(1, 100)
	var roll_target = int(crit_chance * 100)
	if roll <= roll_target:
		calculated_damage = calculated_damage * GameManager.player.current_stats[StatusEffect.PlayerStatEnum.CRITICAL_HIT_DAMAGE_MULTIPLIER]
		owner_gun.crit_damage(calculated_damage)
	return calculated_damage


func anim_countdown_tick(tick_time: float, scale_mod: float, colour: Color) -> void:
	var tween := get_tree().create_tween()
	var reset_scale: float = 0.6
	var max_scale: float = 1.2 + scale_mod
	tween.set_parallel(false)
	tween.tween_property(mesh, "scale", Vector3(0.6, 0.6, 0.6), tick_time * 0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(mesh, "scale", Vector3(max_scale, max_scale, max_scale), tick_time * 0.25).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(mesh.mesh.material, "albedo_color", colour.lerp(Color.WHITE, 0.2), tick_time * 0.25).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(mesh.mesh.material, "emission_energy_multiplier", 1 + scale_mod, tick_time * 0.25).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_callback(tick_sfx_player.play)
	tween.tween_property(mesh, "scale", Vector3(reset_scale, reset_scale, reset_scale), tick_time * 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(mesh.mesh.material, "albedo_color", colour, tick_time * 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	await tween.finished
	
	return


func anim_countdown_final_tick(tick_time: float, scale_mod: float, colour: Color) -> void:
	var tween := get_tree().create_tween()
	var reset_scale: float = 0.6
	var max_scale: float = 1.2 + scale_mod
	tween.set_parallel(false)
	tween.tween_property(mesh, "scale", Vector3(max_scale, max_scale, max_scale), tick_time * 0.5).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(mesh.mesh.material, "albedo_color", colour.lerp(Color.RED, 0.8), tick_time * 0.5).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(mesh.mesh.material, "emission_energy_multiplier", 4, tick_time * 0.5).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	tween.tween_callback(tick_sfx_player.play)
	tween.tween_property(mesh, "scale", Vector3(0.1, 0.1, 0.1), tick_time * 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	await tween.finished
	
	return
