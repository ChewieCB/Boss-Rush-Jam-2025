extends BossCore

signal intro_drop_landed

@export var arena_1_center: Marker3D
@export var arena_2_center: Marker3D

@export_category("Movement")
@export var MOVE_SPEED: float = 6
@onready var move_speed: float = MOVE_SPEED:
	set(value):
		move_speed = value
		navigation_component.current_speed = move_speed
@export var wave_amplitude: float = 7.0
@export var wave_frequency: float = 5.0

var boss_origin: Node
var elevator_spawns: Array[Node]
var sub_elevator_doors: Array[SlidingDoor]
var sub_elevator_lights: Array[Node3D]
var active_spawn: Node
var active_sub_door: SlidingDoor
var active_sub_light: Node3D

var previous_phase: String = "start_melee_combo_attack"

var melee_phase_count: int = 0

var intro_drop_landed_y: float = 0.0
@export var intro_height_margin: float = 0.2
@export var intro_spawn_marker: Marker3D
@export var laser_spawn_markers: Array[Marker3D]

var next_attack: String = ""
var prev_attack: String = ""

@export var sfx_intro_land: Array[AudioStream]

@export_group("Attacks")
@onready var hurtbox_collider: CollisionShape3D = $Hurtbox/CollisionShape3D
@export var hurtbox_range_close: float = 2.0
@export var hurtbox_range_far: float = 3.8
@export var max_sequential_melee_phases: int = 3
@export var max_sequential_ranged_phases: int = 3
#
@export var tutorial_melee_distance: float = 3.0
@export var tutorial_melee_radius: float = 3.0
@export var melee_distance: float = 5.0
@export var melee_radius: float = 5.0

@export_subgroup("Swipe")
@export var swipe_damage: float = 14.0
# SFX
@export var sfx_swipe: Array[AudioStream]
@export var sfx_swipe_miss: Array[AudioStream]
@export_subgroup("Hook")
@export var hook_damage: float = 12.0
# SFX
@export var sfx_kick: Array[AudioStream]
@export_subgroup("Backswipe")
@export var backswipe_damage: float = 16.0
# SFX
@export var sfx_backswipe: Array[AudioStream]
@export_subgroup("Slam")
@export var slam_damage: float = 26.0
@export var slam_delay: float = 0.3
@export var slam_time: float = 0.9
@export var slam_particles: GPUParticles3D
@export var slam_wave_material: StandardMaterial3D
@export var slam_spawn_marker: Marker3D
# SFX
@export var sfx_jump: Array[AudioStream]
@export var sfx_slam: Array[AudioStream]
@export var sfx_wave_loop: Array[AudioStream]
@export var sfx_wave_impact: Array[AudioStream]
@export_subgroup("Nailguns")
@export var nail_projectile: PackedScene
@export var proj_spawn_l: Marker3D
@export var proj_spawn_r: Marker3D
@export var num_bursts: int = 1
@export var shots_per_burst: int = 12
@export var delay_between_burst: float = 0.5
@export var nail_damage: float = 7.0
#
@export var tutorial_strafe_distance: float = 12.0
@export var tutorial_strafe_radius: float = 12.0
# SFX
@export var sfx_nail_equip: Array[AudioStream]
@export var sfx_nail_shot: Array[AudioStream]
@export var sfx_nail_unequip: Array[AudioStream]
@export_subgroup("Laser AoE")
@export var laser_aoe: PackedScene
@export var laser_spawn: Marker3D
@export var laser_damage: float = 40.0
var aoe_warn_decal: Decal
var laser_target_pos: Vector3
@export var laser_aoe_marker: CompressedTexture2D
@onready var laser_particles: GPUParticles3D = $DebugLaserPivot/DebugLaser/LaserSpawn/LaserEndParticles
# SFX
@export var sfx_laser_arm: Array[AudioStream]
@export var sfx_laser_charging: Array[AudioStream]
@export var sfx_laser_shoot: Array[AudioStream]
@export var sfx_laser_disarm: Array[AudioStream]


func _ready() -> void:
	super()
	hurtbox_collider.shape.size.z = hurtbox_range_close


func activate() -> void:
	super ()
	#state_chart.send_event("start_intro")
	state_chart.send_event("start_intro")
	state_chart.send_event("start_tutorial_arena_1")


func _physics_process(_delta: float) -> void:
	#super(delta)
	return


func select_attack_phase_1() -> void:
	var new_phase: String
	
	# If we've just done a melee attack, keep doing melee attacks until we
	# run out of sequential attacks tokens
	#
	# When we run out, trigger a smokescreen
	#
	# When the boss is smokescreened away, pick either the nailgun or laser
	# attack.
	#
	# If the nailgun attack is chosen, teleport the boss to an elevator, open it,
	# and trigger the nailgun attack.
	#
	# At the end of the nailgun attack, if we have ranged attack tokens left
	# return to the elevator and pick another ranged attack. Otherwise exit the
	# elevator with a melee attack.
	#
	# If the laser attack is chosen, teleport to a laser spawn point, and trigger
	# the laser attack.
	#
	# At the end of the laser attack, retreat into the ceiling, if we have ranged
	# attack tokens left pick another ranged attack. Otherwise teleport to an elevator
	# and exit with a melee attack.
	
	#if previous_phase == "start_melee_combo_attack":
		#if melee_phase_count < max_sequential_melee_phases:
			#new_phase = "start_melee_combo_attack"
		#else:
			#melee_phase_count = 0
			#new_phase = "start_smokescreen"
	#
	#elif previous_phase == "start_smokescreen":
		#if ranged_phase_count < max_sequential_ranged_phases:
			#new_phase = "start_smokescreen"
		#else:
			#ranged_phase_count = 0
	new_phase = "start_melee_combo_attack"
	
	previous_phase = new_phase
	state_chart.send_event(new_phase)


func damage_in_hurtbox(damage: float, stun: bool = false) -> void:
	if target in hurtbox.get_overlapping_bodies():
		#sfx_player.stream = sfx_melee.pick_random()
		#sfx_player.play()
		target.health_component.damage(damage)
		if stun:
			target.stun(1.2)


func swipe() -> void:
	var sfx_player = get_available_sfx_player()
	var sfx_arr: Array[AudioStream] = sfx_swipe_miss
	if target.global_position.distance_to(self.global_position) < 5.0:
		sfx_arr = sfx_swipe
		target.health_component.damage(swipe_damage)
	
	if sfx_player:
		sfx_player.stream = sfx_arr.pick_random()
		sfx_player.play()


func hook() -> void:
	var sfx_player = get_available_sfx_player()
	var sfx_arr: Array[AudioStream] = sfx_swipe_miss
	if target.global_position.distance_to(self.global_position) < 5.0:
		sfx_arr = sfx_kick
		target.health_component.damage(hook_damage)
	
	if sfx_player:
		sfx_player.stream = sfx_arr.pick_random()
		sfx_player.play()


func backswipe() -> void:
	var sfx_player = get_available_sfx_player()
	var sfx_arr: Array[AudioStream] = sfx_swipe_miss
	if target.global_position.distance_to(self.global_position) < 5.0:
		sfx_arr = sfx_backswipe
		target.health_component.damage(backswipe_damage)
	
	if sfx_player:
		sfx_player.stream = sfx_arr.pick_random()
		sfx_player.play()


#### Phase 1 | Melee Combo
# TARGETING
func _on_melee_combo_targeting_state_entered() -> void:
	debug_state_label.text = "Melee Combo | Targeting"
	melee_phase_count += 1
	
	hurtbox.set_deferred("monitoring", true)
	state_chart.send_event("start_moving")
	
	if active_sub_door:
		await get_tree().create_timer(1.6).timeout
		active_sub_light.yellow()
		active_sub_door.close()
		await active_sub_door.anim_player.animation_finished
		active_sub_light.red()


func _on_melee_combo_targeting_state_physics_processing(delta: float) -> void:
	orbit_towards_player(delta)
	velocity.y -= GRAVITY * delta
	move_and_slide()
	if self.global_position.distance_to(target.global_position) < 3.0:
		state_chart.send_event("start_attack")
	#elif self.global_position.distance_to(target.global_position) > 12:
		#select_attack()


# SWIPE
func _on_melee_combo_swipe_state_entered() -> void:
	debug_state_label.text = "Melee Combo | Swipe"
	hurtbox.set_deferred("monitoring", true)
	
	state_chart.send_event("start_targeting")
	
	await _telegraph_attack()
	#sfx_player.stream = sfx_melee.pick_random()
	#sfx_player.play()
	anim_player.play("elevator_boss/swipe")
	await anim_player.animation_finished
	
	hurtbox_collider.shape.size.z = hurtbox_range_far
	
	if target in hurtbox.get_overlapping_bodies():
		state_chart.send_event("melee_attack")
	else:
		if randf() < 0.5:
			state_chart.send_event("melee_backstep")
		else:
			anim_player.play("elevator_boss/swipe_end")
			await anim_player.animation_finished
			state_chart.send_event("combo_end")


func _on_melee_combo_swipe_state_physics_processing(delta: float) -> void:
	velocity.x = lerp(velocity.x, 0.0, 0.6)
	velocity.z = lerp(velocity.z, 0.0, 0.6)
	velocity.y -= GRAVITY * delta
	move_and_slide()


# HOOK
func _on_melee_combo_hook_state_entered() -> void:
	debug_state_label.text = "Melee Combo | Hook"
	hurtbox.set_deferred("monitoring", true)
	
	state_chart.send_event("start_targeting")
	
	await _telegraph_attack()
	#sfx_player.stream = sfx_melee.pick_random()
	#sfx_player.play()
	anim_player.play("elevator_boss/kick")
	await anim_player.animation_finished
	
	
	if target in hurtbox.get_overlapping_bodies():
		state_chart.send_event("melee_backswing")
	else:
		if randf() < 0.5:
			state_chart.send_event("melee_backstep")
		else:
			anim_player.play("elevator_boss/kick_end")
			await anim_player.animation_finished
			state_chart.send_event("combo_end")


func _on_melee_combo_hook_state_physics_processing(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	move_and_slide()


func _on_melee_combo_backswing_state_entered() -> void:
	debug_state_label.text = "Melee Combo | Backswing"
	hurtbox.set_deferred("monitoring", true)
	
	state_chart.send_event("start_targeting")
	
	await _telegraph_attack()
	#sfx_player.stream = sfx_melee.pick_random()
	#sfx_player.play()
	anim_player.play("elevator_boss/backswipe")
	await anim_player.animation_finished

	if randf() < 0.6:
		state_chart.send_event("melee_backstep")
	else:
		state_chart.send_event("combo_end")


func _on_melee_combo_backswing_state_physics_processing(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	move_and_slide()


func _on_melee_combo_leap_back_state_entered() -> void:
	state_chart.send_event("start_targeting")
	
	anim_player.play("elevator_boss/slam_jump_prep")
	await anim_player.animation_finished
	
	# TODO - raycast this to make sure we don't overshoot
	var goal_pos = self.global_position + self.basis.z * 5.0
	var nav_pos = NavigationServer3D.map_get_closest_point(navigation_component.nav_map_rid, goal_pos)
	
	await jump_to_pos(nav_pos, 1.6)
	#var jump_results = charge_back_jump(nav_pos, 1.6)
	#
	#var sfx_player = get_available_sfx_player()
	#if sfx_player:
		#sfx_player.stream = sfx_jump.pick_random()
		#sfx_player.play()
	#anim_player.play("elevator_boss/slam_jump_up")
	##await anim_player.animation_finished
	#vel_vertical = 0
	#self.velocity = jump_results[0]
	#var time_up = jump_results[1]
	#var time_down = jump_results[2]
	#
	#await get_tree().create_timer(time_up).timeout
	## Subtract the time the jump down animation lasts so we can sync the impact
	#var hangtime: float = time_down - 0.15
	#await get_tree().create_timer(hangtime).timeout
	#anim_player.play("elevator_boss/slam_jump_down")
	#await anim_player.animation_finished
	
	state_chart.send_event("melee_line")


func jump_to_pos(pos: Vector3, height: float = 20.0, debug: bool = false) -> void:
	var jump_results = charge_back_jump(pos, height, debug)
	
	var sfx_player = get_available_sfx_player()
	if sfx_player:
		sfx_player.stream = sfx_jump.pick_random()
		sfx_player.play()
	anim_player.play("elevator_boss/slam_jump_up")
	#await anim_player.animation_finished
	vel_vertical = 0
	self.velocity = jump_results[0]
	var time_up = jump_results[1]
	var time_down = jump_results[2]
	
	await get_tree().create_timer(time_up).timeout
	# Subtract the time the jump down animation lasts so we can sync the impact
	var hangtime: float = time_down - 0.15
	await get_tree().create_timer(hangtime).timeout
	anim_player.play("elevator_boss/slam_jump_down")
	await anim_player.animation_finished
	return


func _on_melee_combo_leap_back_state_physics_processing(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	move_and_slide()


func _on_melee_combo_slam_line_state_entered() -> void:
	var sfx_player = get_available_sfx_player()
	if sfx_player:
		sfx_player.stream = sfx_slam.pick_random()
		sfx_player.play()
	anim_player.play("elevator_boss/slam_jump_impact")
	#sfx_player.stream = sfx_slam.pick_random()
	#sfx_player.play()
	await anim_player.animation_finished
	
	state_chart.send_event("combo_end")


func _on_melee_combo_slam_line_state_physics_processing(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	move_and_slide()


# RECOVERY
func _on_melee_combo_recover_state_entered() -> void:
	debug_state_label.text = "Melee Combo | Recovery"
	
	prev_attack = "melee_combo"
	
	hurtbox_collider.shape.size.z = hurtbox_range_close
	state_chart.send_event("stop_moving")
	await get_tree().create_timer(attack_recovery_time).timeout
	anim_player.play("RESET")
	
	select_attack()
	
	state_chart.send_event("end_recovery")

func _on_melee_combo_recover_state_physics_processing(delta: float) -> void:
	orbit_player(delta)
	velocity.y -= GRAVITY * delta
	move_and_slide()


#### Phase 1 | Line Slam
# FIXME - I think these state methods are deprecated
func _on_line_slam_targeting_state_entered() -> void:
	_targeting_entered("start_sweep", "Line Slam")

func _on_line_slam_sweep_state_entered() -> void:
	state_chart.send_event("attack_telegraph")
	anim_player.play("elevator_boss/slam_telegraph")
	await anim_player.animation_finished
	state_chart.send_event("attack_start")
	
	# HACK - exit if we send an end_attack event
	if "end_attack" in state_chart._queued_events:
		return
	
	anim_player.play("elevator_boss/slam")
	# SFX
	#big_stack_sfx_player.stream = sfx_chip_sweep_out.pick_random()
	#big_stack_sfx_player.play()
	
	await anim_player.animation_finished
	await get_tree().create_timer(slam_delay).timeout
	
	anim_player.play("RESET")
	state_chart.send_event("end_sweep")

func slam_aoe() -> void:
	var _slam_proj = null # TODO:  = chip_sweep_prefab.instantiate()
	# scene_root.add_child(slam_proj)
	# slam_proj.global_transform = self.global_transform
	
	# var dist_to_player: int = int(slam_proj.global_position.distance_to(target.global_position))
	# slam_proj.anim_time = slam_time / dist_to_player


## Dual Nailguns ranged attack

func _on_ranged_nails_targeting_state_entered() -> void:
	debug_state_label.text = "Dual Nailguns | Targeting"
	ranged_phase_count += 1
	
	desired_distance = 40
	
	state_chart.send_event("start_targeting")
	state_chart.send_event("attack_buildup")
	
	var sfx_player = get_available_sfx_player()
	if sfx_player:
		sfx_player.stream = sfx_nail_equip.pick_random()
		sfx_player.play()
	anim_player.play("elevator_boss/ranged_arm")
	await anim_player.animation_finished
	
	await get_tree().create_timer(0.3).timeout
	state_chart.send_event("start_shooting")


func _on_ranged_nails_targeting_state_physics_processing(_delta: float) -> void:
	return


func _on_ranged_nails_shooting_state_entered() -> void:
	debug_state_label.text = "Dual Nailguns | Shooting"
	await _telegraph_attack()
	await shoot_nail_projectile(num_bursts, shots_per_burst, delay_per_projectile, delay_between_burst)
	
	state_chart.send_event("stop_shooting")


func shoot_nail_projectile(bursts: int, shot_per_burst: int, delay_per_proj: float, delay_per_burst: float) -> void:
	for i in range(bursts):
		for j in range(shot_per_burst):
			# Catch to stop projectiles firing if the boss is killed mid-attack
			if self.health_component.current_health == 0:
				return
			await get_tree().create_timer(delay_per_proj).timeout
			# Alternate firing between each gun
			var spawn_marker = proj_spawn_l if j % 2 == 0 else proj_spawn_r
			var anim_name = "elevator_boss/ranged_shoot_%s" % ["l" if j % 2 == 0 else "r"]
			anim_player.play(anim_name)
			var proj = fire_projectile(nail_projectile, spawn_marker.global_position, sfx_nail_shot)
			var sfx_player = get_available_sfx_player()
			if sfx_player:
				sfx_player.stream = sfx_nail_shot.pick_random()
				sfx_player.play()
			proj.init(nail_damage * GameManager.get_risk_dmg_mult())
		await get_tree().create_timer(delay_per_burst).timeout


func _on_ranged_nails_shooting_state_physics_processing(_delta: float) -> void:
	return


func _on_ranged_nails_recover_state_entered() -> void:
	debug_state_label.text = "Dual Nailguns | Recovering"
	
	state_chart.send_event("attack_end")
	var sfx_player = get_available_sfx_player()
	if sfx_player:
		sfx_player.stream = sfx_nail_unequip.pick_random()
		sfx_player.play()
	anim_player.play("elevator_boss/ranged_disarm")
	
	await get_tree().create_timer(attack_recovery_time).timeout
	anim_player.play("RESET")
	state_chart.send_event("cooldown_end")
	
	desired_distance = DESIRED_DISTANCE
	
	select_attack()
	
	state_chart.send_event("end_recovery")


## Spartan Laser AoE


func _on_laser_aoe_targeting_state_entered() -> void:
	debug_state_label.text = "Spartan Laser Level | Targeting"
	ranged_phase_count += 1
	
	# Clear the sprite state and make sure it's visible
	
	## Pick spawn furthest from player
	#var laser_spawns: Array[Marker3D] = laser_spawn_markers.duplicate()
	#laser_spawns.sort_custom(
		#func(a, b):
			#var a_dist: float = a.global_position.distance_to(target.global_position)
			#var b_dist: float = a.global_position.distance_to(target.global_position)
			#if a_dist > b_dist:
				#return true
			#return false
	#)
	#self.global_position = laser_spawns.front().global_position
	
	desired_distance = 80
	
	state_chart.send_event("start_targeting")
	
	# Laser drops from the sky
	var sfx_player = get_available_sfx_player()
	if sfx_player:
		sfx_player.stream = sfx_laser_arm.pick_random()
		sfx_player.play()
	
	anim_player.play("RESET")
	sprite.modulate.a = 1.0
	anim_player.play("elevator_boss/laser_arm")
	
	await anim_player.animation_finished
	
	state_chart.send_event("charge_laser")


func _on_laser_aoe_charging_state_entered() -> void:
	debug_state_label.text = "Spartan Laser Level | Charging"
	
	state_chart.send_event("attack_buildup")
	# FIXME - why is the audio borked?
	var sfx_player = get_available_sfx_player()
	if sfx_player:
		sfx_player.stream = sfx_laser_charging.pick_random()
		sfx_player.play()
	anim_player.play("elevator_boss/laser_telegraph")
	
	# AoE warning visual
	if aoe_warn_decal:
		aoe_warn_decal.queue_free()
		aoe_warn_decal = null
	
	aoe_warn_decal = Decal.new()
	aoe_warn_decal.texture_albedo = laser_aoe_marker
	aoe_warn_decal.cull_mask = int(pow(2, 1 - 1))
	aoe_warn_decal.size = Vector3(4, 4, 1)
	get_parent().get_parent().add_child(aoe_warn_decal)
	aoe_warn_decal.global_position = laser_spawn.global_position
	aoe_warn_decal.global_rotation = laser_spawn.global_rotation
	aoe_warn_decal.global_position.y = -4.6
	aoe_warn_decal.global_position.x -= 2.0
	
	# laser_aoe_marker
	var warn_tween := get_tree().create_tween()
	warn_tween.tween_property(
		aoe_warn_decal,
		"size:z",
		100,
		0.175 * 6
	)
	#warn_tween.parallel().tween_property(
		#aoe_warn_decal,
		#"global_position",
		#laser_spawn.global_position + -basis.z * 50,
		#0.175 * 6
	#)
	await warn_tween.finished
	await get_tree().create_timer(1.2).timeout
	state_chart.send_event("stop_moving")
	await _telegraph_attack()
	#debug_mesh_instance.queue_free()
	#debug_mesh_instance = null
	# FIXME 
	sfx_player.stop()
	state_chart.send_event("start_firing")


func _on_laser_aoe_charging_state_physics_processing(_delta: float) -> void:
	aoe_warn_decal.global_rotation = self.global_rotation


func _on_laser_aoe_firing_state_entered() -> void:
	var aoe_tween := get_tree().create_tween()
	aoe_tween.tween_property(
		aoe_warn_decal,
		"modulate:a",
		0.0,
		0.8
	)
	aoe_tween.tween_callback(
		func():
			aoe_warn_decal.queue_free()
			aoe_warn_decal = null
	)
	
	# Spawn big cube AoE mesh
	# Check for player presence
	# Damage player
	var sfx_player = get_available_sfx_player()
	if sfx_player:
		sfx_player.stream = sfx_laser_shoot.pick_random()
		sfx_player.play()
	anim_player.play("elevator_boss/laser_fire")
	#laser_particles.emitting = false
	var laser_instance = laser_aoe.instantiate()
	get_parent().add_child(laser_instance)
	laser_instance.global_position = laser_spawn.global_position
	laser_instance.global_position.y -= 2
	laser_instance.global_position.x -= 2
	laser_instance.global_rotation.y = self.global_rotation.y
	
	await anim_player.animation_finished
	await get_tree().create_timer(0.5, false).timeout
	
	#laser_particles.visible = false
	state_chart.send_event("stop_firing")


func _on_laser_aoe_recover_state_entered() -> void:
	debug_state_label.text = "Spartan Laser Level | Recovering"
	
	state_chart.send_event("attack_end")
	
	# Laser raises back up into ceiling
	anim_player.play("elevator_boss/laser_disarm")
	await anim_player.animation_finished
	
	sprite.visible = false
	
	await get_tree().create_timer(attack_recovery_time).timeout
	anim_player.play("RESET")
	sprite.visible = true
	state_chart.send_event("cooldown_end")
	
	desired_distance = DESIRED_DISTANCE
	
	select_attack()
	
	state_chart.send_event("end_recovery")


func _intro_drop() -> void:
	anim_player.play("RESET")
	anim_player.play("elevator_boss/intro")
	self.global_position = intro_spawn_marker.global_position


## SMOKESCREEN ATTACK TRANSITION
# Drop a smokescreen particle emitter to mask the boss teleporting into
# one of the sub-elevators before starting a ranged attack

func _on_smokescreen_idle_state_entered() -> void:
	state_chart.send_event("stop_moving")
	
	var ranged_attacks = [
		"start_dual_nails_attack",
		"start_laser_aoe_attack"
	]
	
	if prev_attack:
		ranged_attacks.erase(prev_attack)
	
	next_attack = ranged_attacks.pick_random()
	
	if active_spawn:
		if self.global_position.distance_to(active_spawn.global_position) < 4:
			state_chart.send_event("start_no_smoke")
			return
	state_chart.send_event("start_smoke")


func _on_smokescreen_smoke_state_entered() -> void:
	# Emit a large amount of smoke particles that conceal the boss,
	# fade/hide the boss sprite, and disable boss collisions with player 
	# and projectiles
	anim_player.play("drop_smoke")
	health_component.is_invincible = true
	health_component.show_damage_text = false
	
	await anim_player.animation_finished
	anim_player.play("RESET")
	
	var new_spawn: Node
	var state_event: String = ""
	match next_attack:
		"start_dual_nails_attack":
			new_spawn = get_elevator_spawn_no_repeats()
			state_event = "open_doors"
			# TODO - configure delay and SFX for door opening
			active_sub_light.yellow()
			sprite.modulate.a = 1.0
		"start_laser_aoe_attack":
			new_spawn = get_furthest_laser_spawn()
			state_event = "start_no_smoke"
	
	# Move the boss to a new spawn point and turn to face the player
	self.global_position = new_spawn.global_position
	self.global_rotation = new_spawn.global_rotation
	
	await get_tree().create_timer(0.6).timeout
	
	state_chart.send_event(state_event)


func _on_smokescreen_move_no_smoke_state_entered() -> void:
	# Retreat back into elevator
	if prev_attack == "start_dual_nails_attack":
		var tween = get_tree().create_tween()
		var forward_dir: Vector3 = - active_sub_door.basis.z
		var peek_pos: Vector3 = self.global_position - forward_dir * 3
		tween.tween_property(
			self, "global_position", peek_pos, 0.5
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		await tween.finished
		
		# Close the doors
		active_sub_light.yellow()
		active_sub_door.close()
		await active_sub_door.anim_player.animation_finished
		
		active_sub_light.red()
		# TODO - configure delay and SFX for door opening
		await get_tree().create_timer(0.3).timeout
	
	match next_attack:
		"start_dual_nails_attack":
			# Move the boss to a new spawn point and turn to face the player
			active_spawn = get_elevator_spawn_no_repeats()
			self.global_position = active_spawn.global_position
			self.global_rotation = active_spawn.global_rotation
			prev_attack = next_attack
			state_chart.send_event("open_doors")
		
		"start_laser_aoe_attack":
			active_spawn = get_furthest_laser_spawn()
			self.global_position = active_spawn.global_position
			prev_attack = next_attack
			state_chart.send_event(next_attack)
			state_chart.send_event("end_smoke")


func _on_smokescreen_open_doors_state_entered() -> void:
	health_component.is_invincible = false
	health_component.show_damage_text = true
	self.collision_layer = int(pow(2, 3 - 1))
	self.collision_mask = int(pow(2, 1 - 1) + pow(2, 2 - 1) + pow(2, 4 - 1) + pow(2, 5 - 1))
	
	active_sub_light.green()
	# TODO - configure delay and SFX for door opening
	await get_tree().create_timer(0.1).timeout
	# Trigger the sub elevator doors to open
	active_sub_door.open()
	
	await active_sub_door.anim_player.animation_finished
	
	# Move the boss out of the elevator to fire
	var tween = get_tree().create_tween()
	var forward_dir: Vector3 = - active_sub_door.basis.z
	var peek_pos: Vector3 = self.global_position + forward_dir * 3
	tween.tween_property(
		self, "global_position", peek_pos, 0.5
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished
	
	prev_attack = next_attack
	state_chart.send_event(next_attack)
	state_chart.send_event("end_smoke")


func get_furthest_laser_spawn() -> Node:
	# Pick spawn furthest from player
	var laser_spawns: Array[Marker3D] = laser_spawn_markers.duplicate()
	laser_spawns.sort_custom(
		func(a, b):
			var a_dist: float = a.global_position.distance_to(target.global_position)
			var b_dist: float = b.global_position.distance_to(target.global_position)
			if a_dist > b_dist:
				return true
			return false
	)
	
	active_spawn = laser_spawns.front()
	return active_spawn


func get_elevator_spawn_no_repeats() -> Node:
	var spawns = elevator_spawns.duplicate()
	
	if active_spawn:
		spawns.erase(active_spawn)
	
	var new_spawn = spawns.pick_random()
	active_spawn = new_spawn
	var idx = elevator_spawns.find(active_spawn)
	active_sub_door = sub_elevator_doors[idx]
	active_sub_light = sub_elevator_lights[idx]
	
	return active_spawn


func charge_back_jump(goal_pos: Vector3 = Vector3.ZERO, charge_jump_height: float = 20.0, debug: bool = false) -> Array:
	var start_pos = self.global_position
	var highest_y = max(start_pos.y, goal_pos.y)
	var apex_y = highest_y + charge_jump_height
	
	var velocity_v: float = sqrt(
		2 * GRAVITY * (apex_y - start_pos.y)
	)
	
	# TODO - make time_up and time_down configurable so we can set a jump time
	var time_up: float = velocity_v / GRAVITY
	var time_down: float = sqrt(2.0 * (apex_y - goal_pos.y) / GRAVITY)
	var time: float = time_up + time_down
	
	var displacement_xz: Vector2 = Vector2(goal_pos.x, goal_pos.z) - Vector2(start_pos.x, start_pos.z)
	var horizontal_distance: float = displacement_xz.length()
	var velocity_h = horizontal_distance / time
	var horizontal_dir: Vector2 = displacement_xz.normalized()
	
	var initial_velocity := Vector3(
		horizontal_dir.x * velocity_h,
		velocity_v,
		horizontal_dir.y * velocity_h,
	)
	
	# Drawing
	if debug:
		var trajectory_points: Array = []
		
		for i in range(1, 151):
			var t = time * float(i) / float(151)
			var x = start_pos.x + initial_velocity.x * t
			var y = start_pos.y + initial_velocity.y * t - 0.5 * GRAVITY * t * t
			var z = start_pos.z + initial_velocity.z * t
			trajectory_points.append(Vector3(x, y, z))
		
		debug_trajectory_mesh.mesh.clear_surfaces()
		debug_trajectory_mesh.mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for p in trajectory_points:
			debug_trajectory_mesh.mesh.surface_set_color(Color.RED)
			debug_trajectory_mesh.mesh.surface_add_vertex(p)
		debug_trajectory_mesh.mesh.surface_end()
		
	return [initial_velocity, time_up, time_down]


func slam_line(_spawn_pos: Vector3, _range: float = 30.0) -> void:
	# Spawn line aoe that grows from boss to target
	spawn_aoe_line(
		self.global_position.distance_to(target.global_position) + 5.0,
		4.0, 0.6,
		slam_damage, slam_time,
		slam_spawn_marker.global_position,
		0.2, false,
		state_chart.send_event.bind("combo_end")
	)


func spawn_aoe_line(
	max_range: float,
	width: float,
	height: float = 2.0,
	damage: float = 10.0,
	spawned_wave_time: float = 1.0,
	area_pos: Vector3 = self.global_position,
	# pushback_source: Node3D = self,
	_spawned_wave_height: float = 0.3,
	_telegraph: bool = false,
	callback: Callable = func(): pass ,
) -> void:
	# Generate a collider
	var area_collider := Area3D.new()
	var area_collider_shape := CollisionShape3D.new()
	var collider_shape := BoxShape3D.new()
	collider_shape.size = Vector3(width, height, 0.1)
	area_collider_shape.shape = collider_shape
	area_collider.add_child(area_collider_shape)
	area_collider.collision_layer = int(pow(2, 7))
	area_collider.collision_mask = int(pow(2, 2 - 1) + pow(2, 7 - 1)) # Player & Cover
	area_collider.monitoring = true
	
	scene_root.add_child(area_collider)
	
	area_collider.global_position = area_pos
	area_collider.global_rotation = self.global_rotation
	area_collider.body_entered.connect(_on_wave_collision.bind(damage, area_collider, max_range))
	#area_collider.body_entered.connect(area_collider.queue_free.unbind(1))
	
	var debug_mesh_instance = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	
	spawned_area_objects.append([area_collider, debug_mesh_instance])
	
	# Generate a visual
	scene_root.add_child(debug_mesh_instance)
	
	debug_mesh_instance.mesh = mesh
	debug_mesh_instance.cast_shadow = false
	debug_mesh_instance.global_position = area_pos
	debug_mesh_instance.global_rotation = self.global_rotation
	
	mesh.size = Vector3(width, height, 0.05)
	mesh.material = slam_wave_material
	
	# Spawn moving wave particles that stay at end of line
	slam_spawn_marker.remove_child(slam_particles)
	scene_root.add_child(slam_particles)
	slam_particles.global_position = debug_mesh_instance.global_position - debug_mesh_instance.basis.z * 0.1
	slam_particles.global_rotation = self.global_rotation + Vector3(0, PI, 0)
	slam_particles.visible = true
	slam_particles.emitting = true
	slam_particles.is_on_floor = true
	
	# Animate the visual
	
	# TODO - SFX
	var slam_sfx_player := AudioStreamPlayer3D.new()
	scene_root.add_child(slam_sfx_player)
	slam_sfx_player.global_position = slam_particles.global_position
	slam_sfx_player.stream = sfx_wave_loop.pick_random()
	slam_sfx_player.play()
	var tween = get_tree().create_tween()
	var end_pos: Vector3 = debug_mesh_instance.global_position - debug_mesh_instance.basis.z * (max_range + 0.1)
	tween.tween_property(mesh, "size:z", max_range, spawned_wave_time).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(debug_mesh_instance, "global_position", debug_mesh_instance.global_position - debug_mesh_instance.basis.z * max_range / 2, spawned_wave_time).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(area_collider_shape, "shape:size:z", max_range, spawned_wave_time).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(area_collider, "global_position", debug_mesh_instance.global_position - debug_mesh_instance.basis.z * max_range / 2, spawned_wave_time).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(slam_particles, "global_position", end_pos, spawned_wave_time).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(slam_sfx_player, "global_position", end_pos, spawned_wave_time).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(debug_mesh_instance.queue_free)
	tween.tween_callback(area_collider.queue_free)
	tween.tween_callback(
		func():
			slam_sfx_player.stop()
			slam_sfx_player.queue_free()
			slam_particles.emitting = false
			await slam_particles.finished
			slam_particles.visible = false
			slam_particles.is_on_floor = false
			slam_spawn_marker.add_child(slam_particles)
			slam_particles.position = Vector3.ZERO
			slam_particles.rotation = Vector3.ZERO
	)
	tween.tween_callback(callback)
	
	await tween.finished
	
	return


func _on_wave_collision(
	body: Node3D,
	aoe_damage: float,
	pushback_source: Node3D = self,
	pushback_radius: float = pushback_source.collider.shape.radius
) -> void:
	if body == target:
		SoundManager.play_sound(sfx_wave_impact.pick_random(), "SFX")
		body.health_component.damage(aoe_damage)
		trigger_pushback(10.0, pushback_source, pushback_radius)
		InputHelper.rumble_medium()


func trigger_pushback(
	force: float,
	pushback_source: Node3D = self,
	pushback_radius: float = pushback_source.collider.shape.radius
) -> void:
	if target.global_position.distance_to(pushback_source.global_position) <= pushback_radius:
		var pushback_vector = pushback_source.global_position.direction_to(target.global_position)
		target.velocity = Vector3.ZERO
		target.vel_horizontal += Vector2(pushback_vector.x, pushback_vector.z) * force
		target.vel_vertical += 8.0


func _on_intro_state_entered() -> void:
	var space_state := get_world_3d().direct_space_state
	var ray_query := PhysicsRayQueryParameters3D.create(self.global_position, self.global_position + Vector3.DOWN * 20.0)
	var result = space_state.intersect_ray(ray_query)
	if result:
		intro_drop_landed_y = result.position.y
		#draw_debug_sphere(result.position, 0.5, Color.RED)
	
	_intro_drop()
	await intro_drop_landed
	
	var sfx_player = get_available_sfx_player()
	if sfx_player:
		sfx_player.stream = sfx_intro_land.pick_random()
		sfx_player.play()
		
	InputHelper.rumble_small()
	target.player_camera.add_trauma(0.3)
	
	anim_player.play("elevator_boss/impact_no_slam")
	await anim_player.animation_finished
	anim_player.play("elevator_boss/idle")
	await get_tree().create_timer(0.8, false).timeout
	state_chart.send_event("start_phase_1")


func _on_intro_state_physics_processing(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	move_and_slide()
	
	if self.global_position.y <= intro_drop_landed_y + intro_height_margin:
		intro_drop_landed.emit()


func _on_phase_1_state_entered() -> void:
	select_attack()


func _on_arena_1_cutscene_state_entered() -> void:
	pass # Replace with function body.


func _on_arena_1_cutscene_state_physics_processing(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	move_and_slide()

### =============================================================
### TUTORIAL PHASES
### =============================================================
## The tutorial fight has sequential phases to ease the player into the mechanics
## Start with a simple ranged strafe
## When the player has done some damage trigger the electric floor aoe
## Then move on to the melee combo
##
## PHASE 1 - BASIC COMBAT
func _on_tutorial_phase_1_state_entered() -> void:
	# Start with a ranged attack, then alternate taunt and ranged attack until a health threshold is reached
	# TODO - update health bar/audio triggers
	pass


# TAUNT
func _on_tutorial_phase_1_taunt_idle_state_entered() -> void:
	state_chart.send_event("start_targeting")
	state_chart.send_event("start_taunt")


func _on_tutorial_phase_1_taunt_taunting_state_entered() -> void:
	anim_player.speed_scale = 0.5
	anim_player.play("elevator_boss/taunt")
	await anim_player.animation_finished
	anim_player.speed_scale = 1.0
	
	state_chart.send_event("end_taunt")

func _on_tutorial_phase_1_taunt_taunting_state_physics_processing(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	move_and_slide()


func _on_tutorial_phase_1_taunt_recover_state_entered() -> void:
	state_chart.send_event("attack_end")
	await get_tree().create_timer(attack_recovery_time).timeout
	
	state_chart.send_event("cooldown_end")
	state_chart.send_event("start_ranged_naiils_strafe")
	# Reset the current state to Targeting
	state_chart.send_event("end_recovery")


# NAILS
func _on_tutorial_phase_1_strafing_nails_targeting_state_entered() -> void:
	debug_state_label.text = "Strafing Nailguns | Targeting"
	
	desired_distance = tutorial_strafe_distance
	orbit_radius = tutorial_strafe_radius
	
	navigation_component.follow_target = false
	state_chart.send_event("start_moving")
	#state_chart.send_event("start_targeting")
	state_chart.send_event("attack_buildup")
	
	var sfx_player = get_available_sfx_player()
	if sfx_player:
		sfx_player.stream = sfx_nail_equip.pick_random()
		sfx_player.play()
	anim_player.play("elevator_boss/ranged_arm")
	await anim_player.animation_finished
	
	# TODO - tweak/increase the strafing time depending on tutorial progress/difficulty
	await get_tree().create_timer(1.2).timeout
	state_chart.send_event("start_shooting")


func _on_tutorial_phase_1_strafing_nails_targeting_state_physics_processing(delta: float) -> void:
	orbit_pos(arena_1_center.global_position, delta, true)
	velocity.y -= GRAVITY * delta
	move_and_slide()


func _on_tutorial_phase_1_strafing_nails_shooting_state_entered() -> void:
	debug_state_label.text = "Dual Nailguns | Shooting"
	await _telegraph_attack()
	# TODO - replace magic numbers with export vars
	await shoot_nail_projectile(1, 6, 0.5, 1.6)
	
	state_chart.send_event("stop_shooting")


func _on_tutorial_phase_1_strafing_nails_shooting_state_physics_processing(delta: float) -> void:
	orbit_pos(arena_1_center.global_position, delta, true)
	velocity.y -= GRAVITY * delta
	move_and_slide()


func _on_tutorial_phase_1_strafing_nails_recover_state_entered() -> void:
	debug_state_label.text = "Dual Nailguns | Recovering"
	
	state_chart.send_event("start_targeting")
	state_chart.send_event("attack_end")
	var sfx_player = get_available_sfx_player()
	if sfx_player:
		sfx_player.stream = sfx_nail_unequip.pick_random()
		sfx_player.play()
	anim_player.play("elevator_boss/ranged_disarm")
	
	await get_tree().create_timer(1.0).timeout
	anim_player.play("RESET")
	state_chart.send_event("cooldown_end")
	
	desired_distance = DESIRED_DISTANCE
	
	state_chart.send_event("start_taunt_attack")
	state_chart.send_event("end_recovery")
