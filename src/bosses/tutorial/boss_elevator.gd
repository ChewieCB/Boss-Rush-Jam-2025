extends BossCore

@export_category("Movement")
@export var MOVE_SPEED: float = 10.0
@onready var move_speed: float = MOVE_SPEED:
	set(value):
		move_speed = value
		navigation_component.current_speed = move_speed
@export var wave_amplitude: float = 7.0
@export var wave_frequency: float = 5.0

var boss_origin: Node
var elevator_spawns: Array[Node]
var sub_elevator_doors: Array[SlidingDoor]
var active_spawn: Node
var active_sub_door: SlidingDoor

var previous_phase: String = "start_melee_combo_attack"

var melee_phase_count: int = 0


@export_group("Attacks")
@onready var hurtbox_collider: CollisionShape3D = $Hurtbox/CollisionShape3D
@export var hurtbox_range_close: float = 3.5
@export var hurtbox_range_far: float = 5.5
@export var sfx_melee: Array[AudioStream]
@export_subgroup("Swipe")
@export var swipe_damage: float = 7.0
@export_subgroup("Hook")
@export var hook_damage: float = 8.0
@export_subgroup("Slam")
@export var slam_delay: float = 0.3
@export var slam_time: float = 0.5
@export_subgroup("Nailguns")
@export var nail_projectile: PackedScene
@export var proj_spawn_l: Marker3D
@export var proj_spawn_r: Marker3D
@export var num_bursts: int = 1
@export var shots_per_burst: int = 12
@export var delay_between_burst: float = 0.5
@export var nail_damage: float = 3.0
# SFX
@export var sfx_nail_shot: Array[AudioStream]
@export_subgroup("Laser AoE")
@export var laser_aoe: PackedScene
@export var laser_spawn: Marker3D
@export var laser_damage: float = 40.0
var aoe_warn_decal: Decal
@export var laser_aoe_marker: CompressedTexture2D
@onready var laser_particles: GPUParticles3D = $DebugLaserPivot/DebugLaser/LaserSpawn/LaserEndParticles


func _ready() -> void:
	super()
	hurtbox_collider.shape.size.z = hurtbox_range_close


func activate() -> void:
	super ()
	#state_chart.send_event("start_intro")
	state_chart.send_event("activate")


func _physics_process(delta: float) -> void:
	super(delta)


func select_attack_phase_1() -> void:
	var new_phase: String
	
	if previous_phase == "start_melee_combo_attack":
		if melee_phase_count < max_sequential_phases:
			if randf() < 0.7:
				new_phase = "start_melee_combo_attack"
			else:
				melee_phase_count = 0
				new_phase = "start_smokescreen"
		else:
			melee_phase_count = 0
			new_phase = "start_smokescreen"
	
	elif previous_phase == "start_smokescreen":
		if ranged_phase_count < max_sequential_phases:
			new_phase = "start_smokescreen"
		else:
			ranged_phase_count = 0
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
	if target.global_position.distance_to(self.global_position) < 5.0:
		target.health_component.damage(swipe_damage)


func hook() -> void:
	if target.global_position.distance_to(self.global_position) < 5.0:
		target.health_component.damage(hook_damage)


#### Phase 1 | Melee Combo
# TARGETING
func _on_melee_combo_targeting_state_entered() -> void:
	debug_state_label.text = "Melee Combo | Targeting"
	melee_phase_count += 1
	
	# DEBUG - to be replaced with sprite frames for each attack
	$DebugAnimPivot.visible = true
	$DebugLaserPivot.visible = false
	$DebugRangedPivot.visible = false
	
	hurtbox.set_deferred("monitoring", true)
	state_chart.send_event("start_moving")

func _on_melee_combo_targeting_state_physics_processing(delta: float) -> void:
	orbit_towards_player(delta)
	if target in hurtbox.get_overlapping_bodies():
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
		state_chart.send_event("combo_end")


func _on_melee_combo_swipe_state_physics_processing(delta: float) -> void:
	velocity.x = lerp(velocity.x, 0.0, 0.6)
	velocity.z = lerp(velocity.z, 0.0, 0.6)


# HOOK
func _on_melee_combo_hook_state_entered() -> void:
	debug_state_label.text = "Melee Combo | Hook"
	hurtbox.set_deferred("monitoring", true)
	
	state_chart.send_event("start_targeting")
	
	await _telegraph_attack()
	#sfx_player.stream = sfx_melee.pick_random()
	#sfx_player.play()
	anim_player.play("elevator_boss/backswipe")
	await anim_player.animation_finished
	
	state_chart.send_event("combo_end")


# RECOVERY
func _on_melee_combo_recover_state_entered() -> void:
	debug_state_label.text = "Melee Combo | Recovery"
	
	hurtbox_collider.shape.size.z = hurtbox_range_close
	state_chart.send_event("stop_moving")
	await get_tree().create_timer(attack_recovery_time).timeout
	anim_player.play("RESET")
	
	select_attack()
	
	state_chart.send_event("end_recovery")

func _on_melee_combo_recover_state_physics_processing(delta: float) -> void:
	orbit_player(delta)


#### Phase 1 | Line Slam
func _on_line_slam_targeting_state_entered() -> void:
	_targeting_entered("start_sweep", "Chip Sweep")

func _on_line_slam_sweep_state_entered() -> void:
	debug_state_label.text = "Chip Sweep | Sweep"
	
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
	
	# DEBUG - to be replaced with sprite frames for each attack
	$DebugAnimPivot.visible = false
	$DebugLaserPivot.visible = false
	$DebugRangedPivot.visible = true
	
	desired_distance = 40
	
	state_chart.send_event("start_targeting")
	state_chart.send_event("attack_buildup")
	await get_tree().create_timer(0.8).timeout
	state_chart.send_event("start_shooting")


func _on_ranged_nails_targeting_state_physics_processing(delta: float) -> void:
	orbit_player(delta)


func _on_ranged_nails_shooting_state_entered() -> void:
	debug_state_label.text = "Dual Nailguns | Shooting"
	
	await _telegraph_attack()
	
	for i in num_bursts:
		for j in shots_per_burst:
			await get_tree().create_timer(delay_per_projectile).timeout
			# Alternate firing between each gun
			var spawn_marker = proj_spawn_l if j % 2 == 0 else proj_spawn_r
			var anim_name = "elevator_boss/ranged_shoot_%s" % ["l" if j % 2 == 0 else "r"]
			anim_player.play(anim_name)
			var proj = fire_projectile(nail_projectile, spawn_marker.global_position, sfx_nail_shot)
			proj.init(nail_damage * GameManager.get_risk_dmg_mult())
		await get_tree().create_timer(delay_between_burst).timeout
	
	state_chart.send_event("stop_shooting")


func _on_ranged_nails_shooting_state_physics_processing(delta: float) -> void:
	orbit_player(delta)


func _on_ranged_nails_recover_state_entered() -> void:
	debug_state_label.text = "Dual Nailguns | Recovering"
	
	state_chart.send_event("attack_end")
	await get_tree().create_timer(attack_recovery_time).timeout
	state_chart.send_event("cooldown_end")
	
	desired_distance = DESIRED_DISTANCE
	
	select_attack()
	
	state_chart.send_event("end_recovery")


## Spartan Laser AoE


func _on_laser_aoe_targeting_state_entered() -> void:
	debug_state_label.text = "Spartan Laser Level | Targeting"
	ranged_phase_count += 1
	
	# DEBUG - to be replaced with sprite frames for each attack
	$DebugAnimPivot.visible = false
	$DebugLaserPivot.visible = true
	$DebugRangedPivot.visible = false
	
	# TODO - spawn in elevator and sort positions, telegraphing, etc.
	
	desired_distance = 80
	
	state_chart.send_event("start_targeting")
	anim_player.play("elevator_boss/laser_arm")
	await anim_player.animation_finished
	state_chart.send_event("charge_laser")


func _on_laser_aoe_charging_state_entered() -> void:
	debug_state_label.text = "Spartan Laser Level | Charging"
	
	state_chart.send_event("attack_buildup")
	anim_player.play("elevator_boss/laser_telegraph")
	laser_particles.visible = true
	laser_particles.emitting = true
	
	# AoE warning visual
	if aoe_warn_decal:
		aoe_warn_decal.queue_free()
		aoe_warn_decal = null
	
	aoe_warn_decal = Decal.new()
	aoe_warn_decal.texture_albedo = laser_aoe_marker
	aoe_warn_decal.cull_mask = pow(2, 1-1)
	aoe_warn_decal.size = Vector3(4, 4, 1)
	get_parent().get_parent().add_child(aoe_warn_decal)
	aoe_warn_decal.global_position = laser_spawn.global_position
	aoe_warn_decal.global_rotation = laser_spawn.global_rotation
	aoe_warn_decal.global_position.y = -4.6
	
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
	#await get_tree().create_timer(0.175 * 6).timeout
	state_chart.send_event("stop_moving")
	await _telegraph_attack()
	#debug_mesh_instance.queue_free()
	#debug_mesh_instance = null
	state_chart.send_event("start_firing")


func _on_laser_aoe_charging_state_physics_processing(delta: float) -> void:
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
	anim_player.play("elevator_boss/laser_fire")
	laser_particles.emitting = false
	var laser_instance = laser_aoe.instantiate()
	get_parent().add_child(laser_instance)
	laser_instance.global_position = laser_spawn.global_position
	laser_instance.global_rotation.y = self.global_rotation.y
	
	laser_particles.visible = false
	state_chart.send_event("stop_firing")


func _on_laser_aoe_recover_state_entered() -> void:
	debug_state_label.text = "Spartan Laser Level | Recovering"
	
	state_chart.send_event("attack_end")
	await get_tree().create_timer(attack_recovery_time).timeout
	state_chart.send_event("cooldown_end")
	
	desired_distance = DESIRED_DISTANCE
	
	select_attack()
	
	state_chart.send_event("end_recovery")



## SMOKESCREEN ATTACK TRANSITION
# Drop a smokescreen particle emitter to mask the boss teleporting into
# one of the sub-elevators before starting a ranged attack

func _on_smokescreen_idle_state_entered() -> void:
	state_chart.send_event("stop_moving")
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
	
	# Move the boss to a new spawn point and turn to face the player
	var new_spawn: Node = get_elevator_spawn_no_repeats()
	self.global_position = new_spawn.global_position
	self.global_rotation = new_spawn.global_rotation
	
	anim_player.play("RESET")
	sprite.modulate.a = 1.0
	self.collision_layer = pow(2, 3)
	state_chart.send_event("open_doors")


func _on_smokescreen_open_doors_state_entered() -> void:
	health_component.is_invincible = false
	health_component.show_damage_text = true
	
	# Trigger the sub elevator doors to open
	active_sub_door.open()
	
	await active_sub_door.anim_player.animation_finished
	
	# Move the boss out of the elevator to fire
	var tween = get_tree().create_tween()
	var forward_dir: Vector3 = -active_sub_door.basis.z
	var peek_pos: Vector3 = self.global_position + forward_dir * 3
	tween.tween_property(
		self, "global_position", peek_pos, 0.5
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished
	
	var ranged_attacks = [
		"start_dual_nails_attack",
		"start_laser_aoe_attack",
	]
	state_chart.send_event(ranged_attacks.pick_random())
	state_chart.send_event("end_smoke")
	
	#await get_tree().create_timer(1.0).timeout
	#active_sub_door.close()


func _on_smokescreen_move_no_smoke_state_entered() -> void:
	var tween = get_tree().create_tween()
	var forward_dir: Vector3 = -active_sub_door.basis.z
	var peek_pos: Vector3 = self.global_position - forward_dir * 3
	tween.tween_property(
		self, "global_position", peek_pos, 0.5
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished
	
	# Close the doors
	active_sub_door.close()
	await active_sub_door.anim_player.animation_finished
	
	# Move the boss to a new spawn point and turn to face the player
	var new_spawn = get_elevator_spawn_no_repeats()
	self.global_position = new_spawn.global_position
	self.global_rotation = new_spawn.global_rotation
	
	state_chart.send_event("open_doors")


func get_elevator_spawn_no_repeats() -> Node:
	var spawns = elevator_spawns.duplicate()
	
	if active_spawn:
		spawns.erase(active_spawn)
	
	var new_spawn = spawns.pick_random()
	active_spawn = new_spawn
	var idx = elevator_spawns.find(active_spawn)
	active_sub_door = sub_elevator_doors[idx]
	
	return active_spawn
