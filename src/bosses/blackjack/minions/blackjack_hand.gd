extends BossCore
class_name BlackjackHand

@onready var dust_particle: GPUParticles3D = $HandDust
@onready var explosion_particle = $DeathExplosion

@export var controller_boss: BossBlackjack
@export var walkable_floor_nav: NavigationRegion3D

@export var slam_shockwave_prefab: PackedScene


var anchor_offset: Vector3

## Attacks
# Hit
var slam_target: Vector3
@export var slam_time: float = 0.35
@export var hit_damage: float = 10

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


func _ready() -> void:
	super()
	state_chart.send_event("start_targeting")


func _physics_process(delta: float) -> void:
	return


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


func _telegraph_attack(_attack_name: String = "") -> void:
	state_chart.send_event("attack_telegraph")
	anim_player.play("telegraph")
	await anim_player.animation_finished
	state_chart.send_event("attack_start")
	return

## PHASE LOGIC

func _on_hit_targeting_state_entered() -> void:
	debug_state_label.text = "Hit | Targeting"
	
	# Play a windup animation, track the player, and then launch the attack
	anim_player.play("blackjack_hand/shake")
	
	state_chart.send_event("start_targeting")
	state_chart.send_event("attack_buildup")
	
	# TODO - play windup anim (shake)
	#anim_player.play("substack/idle")
	await get_tree().create_timer(0.6).timeout
	_telegraph_attack("Hit")
	
	# Target just in front of the players position
	slam_target = target.global_position - target.global_basis.z * 1.15
	# TODO - lock the target pos to the walkable player floor mesh
	#
	# Lock the target pos to the floor
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		slam_target,
		slam_target + Vector3(0, -50, 0),
		int(pow(2, 1 - 1))
	)
	var result = space_state.intersect_ray(query)
	if result:
		slam_target.y = result.position.y
	#draw_debug_sphere(slam_target, 1.0, Color.YELLOW)
	
	state_chart.send_event("hand_slam")


func _on_hit_slamming_state_entered() -> void:
	debug_state_label.text = "Hit | Slamming"
	
	anim_player.play("RESET")
	
	# Quickly zoom towards the target point, 
	# creating a small AoE and some particles on impact
	hurtbox.set_deferred("monitoring", true)
	var slam_tween := get_tree().create_tween()
	slam_tween.tween_property(self, "global_position", slam_target, slam_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await slam_tween.finished
	# TODO - generate explosion and damage
	spawn_dust()
	spawn_explosion()
	
	state_chart.send_event("hand_return")


func _on_hit_returning_state_entered() -> void:
	debug_state_label.text = "Hit | Returning"
	
	hurtbox.set_deferred("monitoring", false)
	
	# We emit the hand_finished signal and the boss uses this to re-anchor the hand
	state_chart.send_event("end_attack")
	state_chart.send_event("hand_finished")


func _on_stand_targeting_state_entered() -> void:
	debug_state_label.text = "Stand | Targeting"
	anim_player.play("blackjack_hand/to_vertical")
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
	
	var stand_tween := get_tree().create_tween()
	stand_tween.tween_property(self, "global_position", stand_hover_target, slam_time * 2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	await stand_tween.finished
	
	state_chart.send_event("hand_double_tap")


func _on_stand_double_tap_state_entered() -> void:
	debug_state_label.text = "Stand | Double Tap"
	
	# Slam the ground vertically twice, spawning AoE waves
	var cached_y: float = self.global_position.y
	
	# Lock target to the floor
	# Lock the target pos to the floor
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		stand_target,
		stand_target + Vector3(0, -50, 0),
		int(pow(2, 1 - 1))
	)
	var result = space_state.intersect_ray(query)
	if result:
		stand_target.y = result.position.y
	
	var slam_tween := get_tree().create_tween()
	for i in range(2):
		slam_tween.tween_property(self, "global_position", stand_target, stand_slam_down_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		slam_tween.tween_callback(
			func(): 
				spawn_dust()
				spawn_explosion()
				spawn_shockwave(self.global_position, stand_wave_radius, stand_wave_damage, stand_wave_time)
		)
		slam_tween.chain().tween_property(self, "global_position:y", cached_y, stand_slam_up_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	
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
	
	anim_player.play("blackjack_hand/to_horizontal")
	anim_player.queue("blackjack_hand/horizontal")
	
	# Return to boss 
	#var target_pos: Vector3 = controller_boss.get_hand_anchor_point(self)
	##draw_debug_sphere(target_pos, 2.0, Color.GREEN)
	#var return_tween := get_tree().create_tween()
	#return_tween.tween_property(self, "global_position", target_pos, slam_time * 3).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN_OUT)
	#
	#await return_tween.finished
	
	state_chart.send_event("end_attack")
	state_chart.send_event("hand_finished")


func spawn_shockwave(spawn_pos: Vector3 = self.global_position, max_radius: float = stand_wave_radius, damage: float = stand_wave_damage, time: float = stand_wave_time) -> void:
	var shockwave = slam_shockwave_prefab.instantiate()
	scene_root.add_child(shockwave)

	shockwave.global_transform = self.global_transform
	shockwave.global_position = spawn_pos
	shockwave.arc_angle = 360
	shockwave.max_radius = max_radius
	shockwave.damage = damage * GameManager.get_risk_dmg_mult()
	shockwave.wave_time = time
	shockwave.start_shockwave()
