extends BossCore
class_name BlackjackHand

signal return_timeout(hand: BlackjackHand)

@onready var dust_particle: GPUParticles3D = $HandDust
@onready var explosion_particle = $DeathExplosion

@export var controller_boss: BossBlackjack
@export var walkable_floor_nav: NavigationRegion3D

@export var slam_shockwave_prefab: PackedScene

var anchor_offset: Vector3
var is_offhand: bool = false  # flag to set handed-ness so we can flip sweep direction

@export var attack_speed_scale: float = 1.0

## Attacks
# Hit
var slam_target: Vector3
@export var slam_time: float = 0.35
@export var hit_damage: float = 10
var slam_tween: Tween

# Stand
var stand_target: Vector3
@export var stand_slam_down_time: float = 0.1
@export var stand_slam_up_time: float = 0.1
@export var stand_range: float = 6.7
@export var stand_wave_radius: float = 8.0
@export var stand_wave_damage: float = 10.0
@export var stand_wave_time: float = 0.8
var stand_repeat_counter: int = 0
@export var stand_repeat_max: int = 3
var shockwave_instance_pool: Array
var stand_tween: Tween

# Sweep
var sweep_start_pos: Vector3
var sweep_end_pos: Vector3
var sweep_target_pos: Vector3
@export var sweep_time: float = 1.6
@export var sweep_offset: float = 2.1
@export var sweep_particles: GPUParticles3D
@export var sweep_card_scene: PackedScene
var sweep_card_instance_pool: Array
var sweep_num_cards: int = 5
var sweep_progress: float = 0.0
var sweep_path_follow: PathFollow3D
var sweep_card_follows := []
var sweep_tween: Tween
# Block
@export var cycle_jitter: float = 0.2
@export var return_timer: Timer

func _ready() -> void:
	super()
	state_chart.send_event("start_targeting")


func _physics_process(delta: float) -> void:
	return


func _on_died() -> void:
	cancel_hand_attack()
	
	state_chart.send_event("stop_moving")
	state_chart.send_event("death")
	state_chart.send_event("deactivate")
	#
	await get_tree().create_timer(attack_recovery_time).timeout
	state_chart.send_event("end_attack")
	return


func _on_health_dead_state_entered() -> void:
	# Override the default state so we don't disable the anim player on death
	#
	# Since hands are re-used after death, most of the death logic is handled
	# in _on_died(), this method currently just changes the sprite colour
	sprite.modulate = Color.DARK_SLATE_BLUE
	death_anim_finished.emit()


func cancel_hand_attack() -> void:
	anim_player.stop()
	anim_player.clear_queue()
	anim_player.play("blackjack_hand/RESET")
	state_chart.send_event("hand_finished")
	for tween in [slam_tween, stand_tween, sweep_tween]:
		if tween:
			tween.kill()
	sweep_particles.emitting = false


func fake_destroy() -> void:
	spawn_dust()
	spawn_explosion()
	sprite.visible = false
	debug_mesh.visible = false
	self.collision_layer = 0
	self.collision_mask = 0
	hurtbox.monitoring = false


func reinstate() -> void:
	self.collision_layer = pow(2, 7-1)
	self.collision_mask = pow(2, 1-1) + pow(2, 4-1) + pow(2, 5-1)
	state_chart.send_event("respawn")
	health_component.current_health = health_component.max_health
	hurtbox.monitoring = true
	sprite.visible = true
	debug_mesh.visible = true


func spawn_dust() -> void:
	dust_particle.restart()
	dust_particle.emitting = true

#func spawn_death_particles() -> void:
	#death_particles.emitting = true

func spawn_explosion() -> void:
	explosion_particle.explosion()


##

func _on_hurtbox_body_entered(body: Node3D) -> void:
	if body is Player:
		body.health_component.damage(hit_damage)


func _telegraph_attack(_attack_name: String = "", time: float = 0.0) -> void:
	state_chart.send_event("attack_telegraph")
	if time > 0.0:
		anim_player.speed_scale = 0.3 / time
	anim_player.play("blackjack_hand/telegraph")
	await anim_player.animation_finished
	anim_player.speed_scale = 1.0
	state_chart.send_event("attack_start")
	return

## PHASE LOGIC

func _on_hit_targeting_state_entered() -> void:
	debug_state_label.text = "Hit | Targeting"
	
	# Play a windup animation, track the player, and then launch the attack
	anim_player.play("blackjack_hand/shake")
	
	state_chart.send_event("start_targeting")
	state_chart.send_event("attack_buildup")
	
	await get_tree().create_timer(1.1).timeout
	_telegraph_attack("Hit")
	
	# Target just in front of the players position
	slam_target = target.global_position - target.global_basis.z * 1.15
	# TODO - lock the target pos to the walkable player floor mesh
	#
	# Lock the target pos to the floor
	var floor_target = slam_target
	floor_target.y = -0.1
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		slam_target,
		floor_target,
		int(pow(2, 1 - 1))
	)
	var result = space_state.intersect_ray(query)
	if result:
		slam_target.y = result.position.y
	#draw_debug_sphere(slam_target, 1.0, Color.YELLOW)
	
	state_chart.send_event("hand_slam")


func _on_hit_slamming_state_entered() -> void:
	debug_state_label.text = "Hit | Slamming"
	
	anim_player.play("blackjack_hand/RESET")
	
	# Quickly zoom towards the target point, 
	# creating a small AoE and some particles on impact
	hurtbox.set_deferred("monitoring", true)
	slam_tween = get_tree().create_tween()
	slam_tween.tween_property(
		self, 
		"global_position", 
		slam_target, 
		slam_time * attack_speed_scale
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await slam_tween.finished
	# TODO - generate explosion and damage
	spawn_dust()
	spawn_explosion()
	
	state_chart.send_event("hand_return")

func _on_hit_slamming_state_physics_process(delta: float) -> void:
	pass


func _on_hit_returning_state_entered() -> void:
	debug_state_label.text = "Hit | Returning"
	
	hurtbox.set_deferred("monitoring", false)
	
	# We emit the hand_finished signal and the boss uses this to re-anchor the hand
	state_chart.send_event("end_attack")
	state_chart.send_event("hand_finished")


func _on_stand_targeting_state_entered() -> void:
	debug_state_label.text = "Stand | Targeting"
	anim_player.play("blackjack_hand/RESET")
	anim_player.queue("blackjack_hand/to_vertical")
	anim_player.queue("blackjack_hand/vertical")
	# Pick a location on the walkable floor to double tap
	# TODO - pick a location a distance away from the player, rotated so the aoe happens in view
	var target_spread_angle: float = randf_range(-PI/2, PI/2)
	# TODO - figure out a good way to maintain separation between hands when choosing a new stand target
	stand_target = target.global_position - (target.global_basis.z * stand_range).rotated(Vector3.UP, target_spread_angle)
	
	state_chart.send_event("hand_move")


func _on_stand_move_to_target_state_entered() -> void:
	debug_state_label.text = "Stand | Move To Target"
	# Fly to the a point above the target location
	var stand_hover_target = stand_target
	stand_hover_target.y = self.global_position.y
	
	stand_tween = get_tree().create_tween()
	stand_tween.tween_property(
		self, 
		"global_position", 
		stand_hover_target, 
		slam_time * 2 * attack_speed_scale
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	await stand_tween.finished
	
	state_chart.send_event("hand_double_tap")


func _on_stand_double_tap_state_entered() -> void:
	debug_state_label.text = "Stand | Double Tap"
	
	# Slam the ground vertically twice, spawning AoE waves
	var cached_y: float = self.global_position.y
	
	# Lock the target pos to the floor
	var space_state = get_world_3d().direct_space_state
	var floor_target = stand_target
	floor_target.y = -0.1
	var query = PhysicsRayQueryParameters3D.create(
		stand_target,
		floor_target,
		int(pow(2, 1 - 1))
	)
	var result = space_state.intersect_ray(query)
	if result:
		stand_target.y = result.position.y
	#draw_debug_sphere(stand_target, 0.5, Color.YELLOW)
	
	slam_tween = get_tree().create_tween()
	for i in range(2):
		slam_tween.tween_property(
			self, 
			"global_position", 
			stand_target, 
			stand_slam_down_time * attack_speed_scale
		).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		slam_tween.tween_callback(
			func(): 
				spawn_dust()
				spawn_explosion()
				var _shockwave = spawn_shockwave()
				if not _shockwave:
					return
				_shockwave.set_deferred("monitoring", true)
				#_shockwave.global_transform = self.global_transform
				_shockwave.global_position = self.global_position
				_shockwave.start_shockwave()
				await _shockwave.finished
				shockwave_instance_pool.push_back(_shockwave)
		)
		slam_tween.chain().tween_property(
			self, 
			"global_position:y", 
			cached_y, 
			stand_slam_up_time * attack_speed_scale
		).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	
	await slam_tween.finished
	
	stand_repeat_counter += 1
	if stand_repeat_counter <= stand_repeat_max:
		var target_spread_angle: float = randf_range(-PI/2, PI/2)
		# TODO - figure out a good way to maintain separation between hands when choosing a new stand target
		stand_target = target.global_position - (target.global_basis.z * stand_range).rotated(Vector3.UP, target_spread_angle)
		# Use the previous floor height to save re-calculating
		if result:
			stand_target.y = result.position.y
		state_chart.send_event("hand_repeat")
	else:
		stand_repeat_counter = 0
		state_chart.send_event("hand_return")


func _on_stand_returning_state_entered() -> void:
	debug_state_label.text = "Stand | Returning"
	
	anim_player.play("blackjack_hand/RESET")
	anim_player.queue("blackjack_hand/to_horizontal")
	anim_player.queue("blackjack_hand/horizontal")
	
	state_chart.send_event("end_attack")
	state_chart.send_event("hand_finished")


func _on_stand_state_exited() -> void:
	anim_player.play("blackjack_hand/RESET")


func spawn_shockwave(spawn_pos: Vector3 = self.global_position, max_radius: float = stand_wave_radius, damage: float = stand_wave_damage, time: float = stand_wave_time) -> Area3D:
	var shockwave = shockwave_instance_pool.pop_front()
	if not shockwave:
		return
	shockwave.set_deferred("monitoring", false)
	shockwave.free_on_finished = false
	shockwave.arc_angle = 360
	shockwave.max_radius = max_radius
	shockwave.damage = damage * GameManager.get_risk_dmg_mult()
	shockwave.wave_time = time
	
	return shockwave


func _on_sweep_targeting_state_entered() -> void:
	debug_state_label.text = "Sweep | Targeting"
	state_chart.send_event("hand_move")


func _on_sweep_move_to_target_state_entered() -> void:
	var target_offset: Vector3 = target.global_position.direction_to(controller_boss.global_position)
	sweep_target_pos = target.global_position + target_offset * sweep_offset
	
	var _angle: float = rad_to_deg(controller_boss.sweep_angle_deg)/2
	var l_angle: float = _angle if is_offhand else -_angle
	var r_angle: float = -_angle if is_offhand else _angle
	# Pick a sweep start point near the target
	sweep_start_pos = target.global_position + (controller_boss.global_basis.z * controller_boss.sweep_dist).rotated(Vector3.UP, l_angle)
	sweep_end_pos = target.global_position + (controller_boss.global_basis.z * controller_boss.sweep_dist).rotated(Vector3.UP, r_angle)
	
	# Lock the target points to the floor
	var space_state = get_world_3d().direct_space_state
	# sweep_start_pos
	var floor_target = sweep_start_pos
	floor_target.y = -0.1
	var query = PhysicsRayQueryParameters3D.create(
		sweep_start_pos,
		floor_target,
		int(pow(2, 1 - 1))
	)
	var result = space_state.intersect_ray(query)
	if result:
		sweep_start_pos.y = result.position.y
	# sweep_target_pos
	floor_target = sweep_start_pos
	floor_target.y = -0.1
	query = PhysicsRayQueryParameters3D.create(
		sweep_target_pos,
		floor_target,
		int(pow(2, 1 - 1))
	)
	result = space_state.intersect_ray(query)
	if result:
		sweep_target_pos.y = result.position.y
	# sweep_end_pos
	floor_target = sweep_start_pos
	floor_target.y = -0.1
	query = PhysicsRayQueryParameters3D.create(
		sweep_end_pos,
		floor_target,
		int(pow(2, 1 - 1))
	)
	result = space_state.intersect_ray(query)
	if result:
		sweep_end_pos.y = result.position.y
	
	# Move to the nearest walkable surface point ready to launch
	var move_tween := get_tree().create_tween()
	move_tween.tween_property(self, "global_position", sweep_start_pos, 0.7)
	
	# Telegraph sweep windup
	anim_player.play("blackjack_hand/shake")
	await get_tree().create_timer(telegraph_time).timeout
	
	state_chart.send_event("hand_sweep")


func _on_sweep_sweeping_state_entered() -> void:
	anim_player.play("blackjack_hand/RESET")
	# Generate a curved path3D to sweep along, 
	# targeting the player position in the middle of the curve.
	var start_pos: Vector3 = sweep_start_pos 
	var goal_pos: Vector3 = sweep_end_pos
	# Generate path to follow
	var path = Path3D.new()
	var curve = Curve3D.new()
	var mid_point: Vector3 = sweep_target_pos  # start_pos.lerp(goal_pos, 0.5) + Vector3(0, 5.0, 0)

	# Calculate a bezier curve contolrs so the curve intersects the target position at some point
	var t: float = 0.5  # Point the curve intersects the target
	var u: float = 1.0 - t
	var w0: float = pow(u, 3)
	var w1: float = 3.0 * pow(u, 2) * t
	var w2: float = 3.0 * u * pow(t, 2)
	var w3: float = pow(t, 3)
	
	var rhs = sweep_target_pos - (w0 * sweep_start_pos + w3 * sweep_end_pos)
	
	# You only get a constraint on the weighted sum of P1,P2
	# Example: pick P1, solve for P2
	var p1 = (sweep_start_pos + sweep_target_pos) * 0.5  # arbitrary choice (e.g. halfway between start and target)
	var p2 = (rhs - (w1 * p1)) / w2
	
	curve.add_point(start_pos, Vector3.ZERO, p1 - sweep_start_pos)
	curve.add_point(goal_pos, p2 - sweep_end_pos, Vector3.ZERO)
	path.curve = curve
	
	# Add the path to the scene
	scene_root.add_child(path)
	sweep_path_follow = PathFollow3D.new()
	path.add_child(sweep_path_follow)

	# Add the hand to the path follow node
	get_parent().remove_child(self)
	sweep_path_follow.add_child(self)
	self.global_position = sweep_path_follow.global_position
	
	#
	hurtbox.set_deferred("monitoring", true)
	sweep_particles.emitting = true
	spawn_dust()
	
	# Spawn face down playing cards throughout the arc movement
	sweep_tween = get_tree().create_tween()
	sweep_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CIRC)
	# Parent hand motion
	sweep_tween.tween_property(
		self, 
		"sweep_progress", 
		1.0, 
		sweep_time * attack_speed_scale
	)
	
	# Card mesh width is 2.08, and we overlap around 0.1-0.3
	var curve_length: float  = curve.get_baked_length()
	var _path_follows := []
	var _cards := []
	# Tween each card in parallel to follow the hand
	for i in range(sweep_num_cards):
		# Create a new path follow for the card to use
		var card_path_follow = PathFollow3D.new()
		path.add_child(card_path_follow)
		
		# Pull a pre-instanced card from the boss' pool of card face scenes
		var _card = sweep_card_instance_pool.pop_front()
		# If we don't have any cards left, spawn a new one and add it to the pool
		if not _card:
			_card = sweep_card_scene.instantiate()
		card_path_follow.add_child(_card)
		
		sweep_card_follows.append({"path_follow": card_path_follow, "card": _card})
		
		_card.global_transform = card_path_follow.global_transform
		_card.rotate_y(PI/2)
		_card.visible = false
		_card.particles.emitting = true
	
	await sweep_tween.finished
	
	# Re-parent hand
	sweep_path_follow.remove_child(self)
	scene_root.add_child(self)
	self.global_position = goal_pos
	
	for kvm in sweep_card_follows:
		var _card = kvm["card"]
		var _follow = kvm["path_follow"]
		if is_instance_valid(_card):
			var cached_pos: Vector3 = _card.global_position
			var cached_trans: Transform3D = _card.global_transform
			_follow.remove_child(_card)
			# Add the card to the tilt mesh so it moves with it
			controller_boss.tilt_mesh.add_child(_card)
			_card.global_transform = cached_trans
			_card.global_position = cached_pos
			sweep_card_instance_pool.push_back(_card)
		
	sweep_card_follows = []
	sweep_progress = 0.0
	
	scene_root.remove_child(path)
	path.queue_free()
	
	state_chart.send_event("hand_return")


func _on_sweep_sweeping_state_physics_processing(delta: float) -> void:
	sweep_path_follow.progress_ratio = sweep_progress
	
	var min_progress_ratio = 0.4
	var max_progress_ratio = 0.6
	for i in range(sweep_num_cards):
		var target_progress_ratio = min_progress_ratio + ((max_progress_ratio - min_progress_ratio) / sweep_num_cards * (i + 1))
		var _path_follow = sweep_card_follows[i]["path_follow"]
		var _card = sweep_card_follows[i]["card"]
		if is_instance_valid(_card):
			var card_progress = clamp(
				(sweep_progress - min_progress_ratio) / (target_progress_ratio - min_progress_ratio),
				0.0,
				1.0
			)
			_path_follow.progress_ratio = lerp(0.0, target_progress_ratio, card_progress)
			_card.visible = card_progress > 0.05


func _on_sweep_returning_state_entered() -> void:
	debug_state_label.text = "Sweep | Returning"
	hurtbox.set_deferred("monitoring", false)
	sweep_particles.emitting = false
	
	await get_tree().create_timer(attack_recovery_time).timeout
	
	state_chart.send_event("end_attack")
	state_chart.send_event("hand_finished")


func _on_return_timer_timeout() -> void:
	return_timeout.emit(self)


func _on_blocking_targeting_state_entered() -> void:
	anim_player.play("blackjack_hand/shake")


func _on_blocking_targeting_state_exited() -> void:
	anim_player.play("blackjack_hand/RESET")
