extends BaseBullet
class_name StickyBombProjectile

signal exploded(explosion_inst: ExplosionDamageArea)

@export var delay_explosion_time = 3
@export var delay_randomness = 0.22
@export var explosion_prefab: PackedScene
@export var explosion_vfx: PackedScene

@onready var raycast: RayCast3D = $RayCast3D
@onready var life_timer: Timer = $LifeTimer
@onready var explode_timer: Timer = $ExplodeTimer
@onready var area: Area3D = $Area3D
@onready var area_col: CollisionShape3D = $Area3D/CollisionShape3D
@onready var homing_area: Area3D = $HomingArea3D
@onready var homing_collision_shape: CollisionShape3D = $HomingArea3D/CollisionShape3D
@onready var mesh: MeshInstance3D = $MeshInstance3D
#@onready var trail: Trail3D = $Trail/Trail3D
@onready var tick_sfx_player: AudioStreamPlayer3D = $TickSFXPlayer
@onready var _root = get_tree().get_root()

var _active_tweens: Array[Tween] = []

const CONTACT_DAMAGE = 1

var sticked = false
var explosion_damage = 0

var _init_dir: Vector3
var _init_start_pos: Vector3


func _ready() -> void:
	await get_parent().ready
	super()
	randomize()
	delay_explosion_time += randf_range(-delay_randomness, delay_randomness)
	explode_timer.wait_time = delay_explosion_time
	life_timer.wait_time = delay_explosion_time


func make_material_unique() -> void:
	mesh.mesh.material = mesh.mesh.material.duplicate(true)


func _process(delta: float) -> void:
	super(delta)


func _physics_process(delta: float) -> void:
	if self.process_mode == Node.PROCESS_MODE_DISABLED:
		return
	
	if sticked:
		return
	
	if raycast.is_colliding():
		hitscan_col_point = raycast.get_collision_point()
		hitscan_col_normal = raycast.get_collision_normal()
		found_hitscal_col = true

	if homing_locked_in and homing_target:
		var target_pos = homing_target.global_position
		if homing_target.has_node("BodyCenter"):
			target_pos = homing_target.get_node("BodyCenter").global_position
		var dir_to_target = global_position.direction_to(target_pos)
		look_at(global_position + dir_to_target)
	elif can_be_aim_guided and life_time >= min_lifetime_before_can_be_aim_guided:
		var aiming_position = GunUtils.get_player_aiming_position()
		var dir_to_target = global_position.direction_to(aiming_position)
		look_at(global_position + dir_to_target)

	velocity = - transform.basis.z * projectile_speed
	global_position += velocity * delta
	travelled_distance += projectile_speed * delta


func init(start_pos: Vector3, dir: Vector3, _damage: int, ricochet_count: int, _speed: float, _max_range: float):
	activate()
	sticked = false
	if homing_strength > 0:
		enable_homing()
	life_timer.start()

	projectile_speed = _speed
	max_range = _max_range
	damage = CONTACT_DAMAGE
	if GameManager.player:
		crit_chance = GameManager.player.current_stats[StatusEffect.PlayerStatEnum.CRITICAL_HIT_CHANCE]
	else:
		crit_chance = GameManager.player_base_stats[StatusEffect.PlayerStatEnum.CRITICAL_HIT_CHANCE]
	explosion_damage = _damage
	current_dir = dir
	ricochet_count_left = ricochet_count
	
	look_at_from_position(start_pos, start_pos + dir)
	_start_countdown_anim()


func _start_countdown_anim() -> void:
	_run_countdown_anim.call_deferred()


func _run_countdown_anim() -> void:
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
		# Exit if deactivated mid-countdown
		if not is_instance_valid(self) or process_mode == Node.PROCESS_MODE_DISABLED \
		or not self.is_inside_tree():
			return
		var duration = tick_durations[i]
		if i == tick_durations.size() - 1:
			await anim_countdown_final_tick(duration, i * 0.55, start_colour.lerp(end_colour, i / tick_durations.size()))
		else:
			await anim_countdown_tick(duration, i * 0.55, start_colour.lerp(end_colour, i / tick_durations.size()))
			tick_sfx_player.volume_db += 4


func ricochet():
	super()
	found_hitscal_col = false
	is_ricochet_shot = true
	
	# Calculate bounce direction
	var bounce_dir = current_dir.bounce(hitscan_col_normal)
	
	# Add slight homing toward last look enemy target if available
	if GameManager.player and is_instance_valid(GameManager.player.last_look_enemy_target):
		var target = GameManager.player.last_look_enemy_target
		var dir_to_target = global_position.direction_to(target.global_position)
		# Blend bounce direction with target direction (small homing factor)
		bounce_dir = bounce_dir.lerp(dir_to_target, RICOCHET_HOMING_STRENGTH).normalized()
	
	init(global_position, bounce_dir, explosion_damage, ricochet_count_left - 1, projectile_speed, max_range)


func _on_life_timer_timeout() -> void:
	destroyed.emit(false)
	finished.emit()


func _on_area_3d_body_entered(body: Node3D) -> void:
	if sticked:
		return
	
	var calculated_damage = calculate_bullet_damage()
	if not calculated_damage:
		return
	
	if body is CharacterBody3D:
		if is_instance_valid(body):
			damage_body(body, calculated_damage)
			stick_bullet(body)
	else:
		if body is Shield:
			body.impact(self.global_position)
			apply_damage_to_health_component(body.health_component, calculated_damage)
			hit_boss = true
		elif "health_component" in body:
			apply_damage_to_health_component(body.health_component, calculated_damage)
			hit_boss = true
		stick_bullet(body)
	
	start_countdown()


func start_countdown() -> void:
	life_timer.stop()
	explode_timer.start()
	impacted.emit(self , true, global_position)


func damage_body(body: Node3D, damage: int = 0) -> void:
	if damage == 0:
		damage = calculate_bullet_damage()
		
	before_damage_applied.emit(body, self )
	damage = calculate_bullet_damage(false) # Recalculate damage after before_damage_applied effect
	apply_damage_to_health_component(body.health_component, damage)
	damage_applied.emit(damage, true, global_position)
	hit_boss = true


func stick_bullet(body: Node3D) -> void:
	#$Area3D/CollisionShape3D.disabled = true
	#$HomingArea3D/CollisionShape3D.disabled = true
	self.reparent.call_deferred(body)
	sticked = true


func enable_homing() -> void:
	homing_area.collision_layer = 0
	homing_area.collision_mask = pow(2, 3-1) + pow(2, 7-1) + pow(2, 8-1)
	homing_collision_shape.set_deferred("disabled", false)
	homing_area.set_deferred("monitoring", true)
	homing_area.set_deferred("monitorable", true)
	homing_collision_shape.shape.radius = homing_strength


func _on_homing_area_3d_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		homing_locked_in = true
		homing_target = body
		homing_area.set_deferred("monitoring", false)


func _on_explode_timer_timeout() -> void:
	var calculated_explosion_damage = calculate_explosion_damage()
	var explosion_inst = ObjectPoolingManager.get_pooled_object(
		ObjectPoolingManager.PooledObjectEnum.EXPLOSION
	)
	explosion_inst.init(calculated_explosion_damage)
	explosion_inst.global_position = self.global_position

	for i in range(infused_status_effect.size()):
		if infused_status_effect[i]:
			explosion_inst.add_status_effect(i + 1)  # Offset for the None enum value
	
	explosion_inst.call_deferred("activate")
	exploded.emit(explosion_inst)
	call_deferred("create_explosion")

	if ricochet_count_left > 0 and found_hitscal_col:
		sticked = false
		self.reparent.call_deferred(get_tree().get_root())
		ricochet()
	else:
		destroyed.emit(hit_boss)
		finished.emit()


func create_explosion() -> void:
	var vfx = ObjectPoolingManager.get_pooled_object(
		ObjectPoolingManager.PooledObjectEnum.EXPLOSION_OLD
	)
	vfx.activate()
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
	vfx.global_position = global_position
	vfx.set_colour.call_deferred(vfx_color)


func change_bullet_color(_new_color: Color):
	super(_new_color)
	if color_changed_count > 1:
		mesh.mesh.material.albedo_color = mesh.mesh.material.albedo_color.lerp(_new_color, 0.5)
		mesh.mesh.material.emission = mesh.mesh.material.emission.lerp(_new_color, 0.5)
		#trail.material_override.albedo_color = trail.material_override.albedo_color.lerp(_new_color, 0.5)
		#trail.material_override.emission = trail.material_override.emission.lerp(_new_color, 0.5)
	else:
		mesh.mesh.material.albedo_color = _new_color
		mesh.mesh.material.emission = _new_color
		#trail.material_override.albedo_color = Color(_new_color.r, _new_color.g, _new_color.b, 0.7)
		#trail.material_override.emission = _new_color


func calculate_explosion_damage():
	if not is_instance_valid(owner_gun):
		return
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
	if not self.is_inside_tree():
		return
	var tween := get_tree().create_tween()
	_active_tweens.append(tween)
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
	
	_active_tweens.erase(tween)
	return


func anim_countdown_final_tick(tick_time: float, scale_mod: float, colour: Color) -> void:
	if not self.is_inside_tree():
		return
	var tween := get_tree().create_tween()
	_active_tweens.append(tween)
	var reset_scale: float = 0.6
	var max_scale: float = 1.2 + scale_mod
	tween.set_parallel(false)
	tween.tween_property(mesh, "scale", Vector3(max_scale, max_scale, max_scale), tick_time * 0.5).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(mesh.mesh.material, "albedo_color", colour.lerp(Color.RED, 0.8), tick_time * 0.5).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(mesh.mesh.material, "emission_energy_multiplier", 4, tick_time * 0.5).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	tween.tween_callback(tick_sfx_player.play)
	tween.tween_property(mesh, "scale", Vector3(0.1, 0.1, 0.1), tick_time * 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	await tween.finished
	
	_active_tweens.erase(tween)
	return


func _activate_visuals() -> void:
	scale = Vector3.ONE
	mesh.scale = Vector3.ONE
	#light.visible = true
	self.visible = true

func _activate_physics() -> void:
	if get_parent() != _root:
		self.reparent.call_deferred(_root)
	
	reset_bullet_stats()
	
	self.process_mode = Node.PROCESS_MODE_INHERIT
	set_physics_process(true)
	
	area.collision_layer = pow(2, 4-1)
	area.collision_mask = pow(2, 1-1) + pow(2, 3-1) + pow(2, 4-1) + pow(2, 5-1) + pow(2, 7-1) + pow(2, 8-1)
	area_col.set_deferred("disabled", false)
	area.set_deferred("monitoring", true)
	area.set_deferred("monitorable", true)
	#homing_collision_shape.set_deferred("disabled", false)
	#homing_area.set_deferred("monitoring", true)
	#homing_area.set_deferred("monitorable", true)
	raycast.set_deferred("enabled", true)


func _deactivate_visuals() -> void:
	self.visible = false

func _deactivate_physics() -> void:
	super()
	
	if get_parent() != _root:
		self.reparent.call_deferred(_root)
	
	for tween in _active_tweens:
		if tween and tween.is_valid():
			tween.kill()
	_active_tweens.clear()
	
	life_timer.stop()
	explode_timer.stop()
	tick_sfx_player.stop()
	
	stop_elemental_particles()
	
	area.collision_layer = 0
	area.collision_mask = 0
	homing_area.collision_layer = 0
	homing_area.collision_mask = 0
	
	area_col.set_deferred("disabled", true)
	area.set_deferred("monitoring", false)
	area.set_deferred("monitorable", false)
	homing_collision_shape.set_deferred("disabled", true)
	homing_area.set_deferred("monitoring", false)
	homing_area.set_deferred("monitorable", false)
	raycast.set_deferred("enabled", false)
	
	self.process_mode = Node.PROCESS_MODE_DISABLED
	set_physics_process(false)
