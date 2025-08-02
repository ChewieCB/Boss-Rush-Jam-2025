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
@export var hurtbox_range_far: float = 4.5
@export var sfx_melee: Array[AudioStream]
@export_subgroup("Swipe")
@export var swipe_damage: float = 7.0
@export_subgroup("Hook")
@export var hook_damage: float = 8.0
@export_subgroup("Slam")
@export var slam_delay: float = 0.3
@export var slam_time: float = 0.5


func _ready() -> void:
	super ()
	hurtbox_collider.shape.size.z = hurtbox_range_close


func activate() -> void:
	super ()
	#state_chart.send_event("start_intro")
	state_chart.send_event("activate")


func _physics_process(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	time_elapsed += delta
	var chase_direction: Vector3 = self.global_position.direction_to(target.global_position)
	var perpendicular: Vector3 = chase_direction.rotated(Vector3.UP, PI / 2)
	var wave_offset = perpendicular * sin(time_elapsed * wave_frequency) * wave_amplitude
	var desired_position = target.global_position + wave_offset
	navigation_component.set_nav_target_position(desired_position)
	move_and_slide()
	
	debug_dist_label.text = str(self.global_position.distance_to(target.global_position))


func select_attack_phase_1() -> void:
	# var dist_to_target = self.global_position.distance_to(target.global_position)
	var _possible_phases = [
		"start_melee_combo_attack",
	]
	state_chart.send_event("start_melee_combo_attack")


func damage_in_hurtbox(damage: float, stun: bool = false) -> void:
	if target in hurtbox.get_overlapping_bodies():
		#sfx_player.stream = sfx_melee.pick_random()
		#sfx_player.play()
		target.health_component.damage(damage)
		if stun:
			target.stun(1.2)


func swipe() -> void:
	target.health_component.damage(swipe_damage)


func hook() -> void:
	target.health_component.damage(hook_damage)


#### Phase 1 | Melee Combo
# TARGETING
func _on_melee_combo_targeting_state_entered() -> void:
	debug_state_label.text = "Melee Combo | Targeting"
	hurtbox.set_deferred("monitoring", true)
	state_chart.send_event("start_moving")

func _on_melee_combo_targeting_state_physics_processing(_delta: float) -> void:
	if target in hurtbox.get_overlapping_bodies():
		state_chart.send_event("start_attack")
	elif self.global_position.distance_to(target.global_position) > 12:
		select_attack()


# SWIPE
func _on_melee_combo_swipe_state_entered() -> void:
	debug_state_label.text = "Melee Combo | Swipe"
	hurtbox.set_deferred("monitoring", true)
	
	state_chart.send_event("stop_moving")
	velocity.x = 0
	velocity.z = 0
	
	#sfx_player.stream = sfx_melee.pick_random()
	#sfx_player.play()
	anim_player.play("elevator_boss/swipe")
	await anim_player.animation_finished
	
	hurtbox_collider.shape.size.z = hurtbox_range_far
	
	if target in hurtbox.get_overlapping_bodies():
		state_chart.send_event("melee_attack")
	else:
		state_chart.send_event("combo_end")


# HOOK
func _on_melee_combo_hook_state_entered() -> void:
	debug_state_label.text = "Melee Combo | Hook"
	hurtbox.set_deferred("monitoring", true)
	
	state_chart.send_event("start_targeting")
	
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
