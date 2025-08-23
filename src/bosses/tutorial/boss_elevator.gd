extends BossCore

@export_category("Movement")
@export var MOVE_SPEED: float = 10.0
@onready var move_speed: float = MOVE_SPEED:
	set(value):
		move_speed = value
		navigation_component.current_speed = move_speed
@export var wave_amplitude: float = 7.0
@export var wave_frequency: float = 5.0
@export var time_elapsed: float = 0.0

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
var laser_instance



func _ready() -> void:
	super ()
	hurtbox_collider.shape.size.z = hurtbox_range_close


func activate() -> void:
	super ()
	#state_chart.send_event("start_intro")
	state_chart.send_event("activate")


func _physics_process(delta: float) -> void:
	super(delta)


func select_attack_phase_1() -> void:
	# var dist_to_target = self.global_position.distance_to(target.global_position)
	var _possible_phases = [
		"start_melee_combo_attack",
		"start_dual_nails_attack",
		"start_laser_aoe_attack",
	]
	state_chart.send_event(_possible_phases.pick_random())


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
	# TODO - start showing/building telegraphing mesh/texture for the AoE
	await get_tree().create_timer(0.175 * 6).timeout
	await _telegraph_attack()
	state_chart.send_event("start_firing")


func _on_laser_aoe_firing_state_entered() -> void:
	# Spawn big cube AoE mesh
	# Check for player presence
	# Damage player
	anim_player.play("elevator_boss/laser_fire")
	laser_instance = laser_aoe.instantiate()
	get_parent().add_child(laser_instance)
	laser_instance.global_position = laser_spawn.global_position
	laser_instance.global_rotation.y = self.global_rotation.y
	
	# TODO - move this into the laser aoe object itself to handle
	var laser_tween := get_tree().create_tween()
	laser_tween.tween_property(
		laser_instance.get_node("MeshInstance3D"), 
		"mesh:material:albedo_color:a",
		0,
		2.0
	)
	laser_tween.tween_callback(
		func():
			laser_instance.queue_free()
			laser_instance = null
			state_chart.send_event("stop_firing")
	)
	
	#state_chart.send_event("stop_firing")


func _on_laser_aoe_recover_state_entered() -> void:
	debug_state_label.text = "Spartan Laser Level | Recovering"
	
	state_chart.send_event("attack_end")
	await get_tree().create_timer(attack_recovery_time).timeout
	state_chart.send_event("cooldown_end")
	
	desired_distance = DESIRED_DISTANCE
	
	select_attack()
	state_chart.send_event("end_recovery")
