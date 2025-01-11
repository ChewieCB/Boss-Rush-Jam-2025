extends BossCore


@onready var debug_phase_label: Label3D = $DebugPhaseLabel

var wheel_rotation_speed: float = 0.6


@export var barrier_phase_count: int = 2
@export var shields_phase_count: int = 1

# Barrier
@export var barrier_sweep_speed: float = 1.7

# Shields
@onready var shields_parent: Node3D = $Shields
@export var shield_scene: PackedScene
@export var shields_max_time: float = 12.0
@onready var shields_timer: Timer = $ShieldsTimer
@export var shield_count: int = 4
@export var shield_distance: float = 6.0
@export var shield_height: float = 3.3


func _ready() -> void:
	GRAVITY = 0.0
	hurtbox.visible = false
	shields_parent.position.y -= 30.0
	shields_timer.wait_time = shields_max_time
	super()



func activate() -> void:
	super()
	state_chart.send_event("start_phase_1")
	change_phase_1()
	#change_phase()


func change_phase_1() -> void:
	var dist_to_target = self.global_position.distance_to(target.global_position)
	var possible_phases = [
		"start_barrier_attack",
		"start_shields_attack",
	]
	if barrier_phase_count == max_sequential_phases:
		possible_phases.erase("start_barrier_attack")
		barrier_phase_count = 0
	if shields_phase_count == max_sequential_phases:
		possible_phases.erase("start_shields_attack")
		shields_phase_count = 0
	
	# If we've somehow exluded all of the possible phases, 
	# the counters have been reset so just call this method again.
	if possible_phases == []:
		change_phase_1()
		return
	
	var new_phase: String = possible_phases[randi_range(0, possible_phases.size() - 1)]
	state_chart.send_event(new_phase)


func change_phase() -> void:
	var dist_to_target = self.global_position.distance_to(target.global_position)
	var possible_phases = [
		"start_ranged_attack",
		"start_area_attack"
	]
	if ranged_phase_count == max_sequential_phases:
		possible_phases.erase("start_ranged_attack")
		ranged_phase_count = 0
	if area_phase_count == max_sequential_phases:
		possible_phases.erase("start_area_attack")
		area_phase_count = 0
	
	# If we've somehow exluded all of the possible phases, 
	# the counters have been reset so just call this method again.
	if possible_phases == []:
		change_phase()
		return
	
	# If the player is too close, don't do area attacks
	if dist_to_target <= area_size / 2:
		possible_phases.erase("start_area_attack")
	else:
		#possible_phases.erase("start_area_attack")
		possible_phases.append("start_area_attack")
	
	# If the player is further away, prioritise charges and area attacks
	possible_phases.append("start_ranged_attack")
	possible_phases.append("start_ranged_attack")
	possible_phases.append("start_ranged_attack")
	possible_phases.append("start_area_attack")
	
	var new_phase: String = possible_phases[randi_range(0, possible_phases.size() - 1)]
	state_chart.send_event(new_phase)


func _on_hurtbox_body_entered(body: Node3D) -> void:
	SoundManager.play_sound(TEMP_sfx_charge_impact)
	if body == target:
		target.health_component.damage(20)
		hurtbox.set_deferred("monitoring", false)
		await get_tree().create_timer(0.2).timeout
		hurtbox.set_deferred("monitoring", true)


func _on_movement_targeting_state_physics_processing(delta: float) -> void:
	if target:
		_turn_towards_target(wheel_rotation_speed, delta)


func _on_phase_1_state_entered() -> void:
	debug_phase_label.text = "Phase 1"


func _on_damage_barrier_targeting_state_entered() -> void:
	debug_state_label.text = "Damage Barrier | Targeting"
	state_chart.send_event("start_targeting")
	hurtbox.visible = true
	await get_tree().create_timer(2.0).timeout
	state_chart.send_event("barrier_attack")


func _on_damage_barrier_spawn_barrier_state_entered() -> void:
	debug_state_label.text = "Damage Barrier | Barrier"
	
	hurtbox.monitoring = true
	
	# TODO - add telegraphing for each sweep
	var tween = get_tree().create_tween()
	tween.tween_property(
		self, "rotation:y", self.rotation.y + 2*PI, barrier_sweep_speed
	).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(1.0)
	tween.tween_property(
		self, "rotation:y", self.rotation.y + 2*PI, barrier_sweep_speed
	).set_ease(Tween.EASE_IN_OUT)
	
	await tween.finished
	state_chart.send_event("barrier_attack_end")


func _on_damage_barrier_spawn_barrier_state_exited() -> void:
	hurtbox.visible = false
	hurtbox.monitoring = false


func _on_damage_barrier_recover_state_entered() -> void:
	debug_state_label.text = "Damage Barrier | Recover"
	await get_tree().create_timer(attack_recovery_time).timeout
	change_phase_1()
	state_chart.send_event("restart_targeting")
	# TODO - add fire again option


func _on_shields_targeting_state_entered() -> void:
	debug_state_label.text = "Shields | Targeting"
	state_chart.send_event("start_targeting")
	await get_tree().create_timer(2.0).timeout
	state_chart.send_event("spawn_shields")


func _on_shields_spawn_shields_state_entered() -> void:
	var rotation_increment: float = 2 * PI / shield_count
	for i in shield_count:
		var new_shield: Shield = shield_scene.instantiate()
		shields_parent.add_child(new_shield)
		new_shield.position.z = shield_distance
		new_shield.position.y = shield_height
		# Rotate the shield around the parent node as a pivot point
		new_shield.global_translate(-shields_parent.global_position)
		new_shield.transform = new_shield.transform.rotated(Vector3.UP, -rotation_increment * (i+1))
		new_shield.global_translate(shields_parent.global_position)
		
		new_shield.destroyed.connect(_check_shields)
		
	shields_parent.visible = true
	var tween = get_tree().create_tween()
	tween.tween_property(shields_parent, "position:y", 0, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(shields_timer.start)
	
	# TODO - add projectile/wave attack at the same time?


func _check_shields() -> void:
	if shields_parent.get_child_count() == 0:
		state_chart.send_event("shields_destroyed")


func _on_shields_spawn_shields_state_physics_processing(delta: float) -> void:
	shields_parent.rotation.y += delta * wheel_rotation_speed * 4


func _on_shields_recover_state_entered() -> void:
	debug_state_label.text = "Shields | Recover"
	await get_tree().create_timer(attack_recovery_time).timeout
	change_phase_1()
	state_chart.send_event("restart_targeting")


func _on_shields_timer_timeout() -> void:
	state_chart.send_event("shields_timeout")


func _on_shields_absorb_state_entered() -> void:
	var health_regained: float = 0.0
	for shield in shields_parent.get_children():
		health_regained += shield.health_component.current_health
		var tween = get_tree().create_tween()
		tween.tween_property(shield, "position", Vector3(0, shield_height, 0), 0.3).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(shield, "scale", Vector3(0, 0, 0), 0.3).set_trans(Tween.TRANS_SINE)
		tween.tween_callback(shield.queue_free)
		tween.tween_callback(health_component.heal.bind(health_regained))
		await tween.finished
	state_chart.send_event("shields_absorbed")
