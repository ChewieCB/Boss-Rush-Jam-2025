extends BossCore
class_name BlackjackHand


@onready var dust_particle: GPUParticles3D = $HandDust
@onready var death_particles: GPUParticles3D = $DeathDust
@onready var explosion_particle = $DeathExplosion

@export var controller_boss: BossBlackjack
@export var walkable_floor_nav: NavigationRegion3D


## Attacks
# Hit
var slam_target: Vector3
@export var slam_time: float = 0.6
@export var hit_damage: float = 10

# Stand
var stand_target: Vector3
@export var stand_slam_down_time: float = 0.1
@export var stand_slam_up_time: float = 0.1
var stand_repeat_counter: int = 0
@export var stand_repeat_max: int = 3


func _ready() -> void:
	super()
	state_chart.send_event("start_targeting")


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
	# Return to the boss slightly slower than the slam speed
	var target_pos: Vector3 = controller_boss.get_hand_anchor_point(self)
	#draw_debug_sphere(target_pos, 2.0, Color.GREEN)
	var return_tween := get_tree().create_tween()
	return_tween.tween_property(self, "global_position", target_pos, slam_time * 3).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN_OUT)
	
	await return_tween.finished
	
	# We emit the hand_finished signal and the boss uses this to re-anchor the hand
	# TODO
	state_chart.send_event("end_attack")
	state_chart.send_event("hand_finished")


func _on_stand_targeting_state_entered() -> void:
	debug_state_label.text = "Stand | Targeting"
	print(self.name, " : ", "Stand | Targeting")
	anim_player.play("blackjack_hand/to_vertical")
	anim_player.queue("blackjack_hand/vertical")
	# Pick a location on the walkable floor to double tap
	# TODO - pick a location a distance away from the player, rotated so the aoe happens in view
	stand_target = target.global_position - (target.global_basis.z * 8.0).rotated(Vector3.UP, randf_range(-PI/4, PI/4))
	#stand_target = NavigationServer3D.map_get_closest_point(walkable_floor_nav.get_navigation_map(), stand_target)
	#draw_debug_sphere(stand_target, 1.5, Color.PURPLE)
	
	state_chart.send_event("hand_move")


func _on_stand_move_to_target_state_entered() -> void:
	debug_state_label.text = "Stand | Move To Target"
	print(self.name, " : ", "Stand | Move To Target")
	# Fly to the a point above the target location
	var stand_tween := get_tree().create_tween()
	var stand_hover_target = stand_target
	stand_hover_target.y = self.global_position.y
	stand_tween.tween_property(self, "global_position", stand_hover_target, slam_time*2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	await stand_tween.finished
	
	state_chart.send_event("hand_double_tap")


func _on_stand_double_tap_state_entered() -> void:
	debug_state_label.text = "Stand | Double Tap"
	print(self.name, " : ", "Stand | Double Tap")
	
	# Slam the ground vertically twice, spawning AoE waves
	var cached_y: float = self.global_position.y
	var slam_tween := get_tree().create_tween()
	for i in range(2):
		slam_tween.chain().tween_property(self, "global_position", stand_target, stand_slam_down_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		slam_tween.tween_callback(
			func(): 
				spawn_dust()
				spawn_explosion()
		)
		slam_tween.chain().tween_property(self, "global_position:y", cached_y, stand_slam_up_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	
	await slam_tween.finished
	# TODO - generate explosion and damage
	#
	# TODO - spawn wave
	#
	stand_repeat_counter += 1
	if stand_repeat_counter <= stand_repeat_max:
		state_chart.send_event("hand_repeat")
	else:
		stand_repeat_counter = 0
		state_chart.send_event("hand_return")


func _on_stand_returning_state_entered() -> void:
	debug_state_label.text = "Stand | Returning"
	print(self.name, " : ", "Stand | Returning")
	anim_player.play("blackjack_hand/to_horizontal")
	anim_player.queue("blackjack_hand/horizontal")
	
	# Return to boss 
	var target_pos: Vector3 = controller_boss.get_hand_anchor_point(self)
	#draw_debug_sphere(target_pos, 2.0, Color.GREEN)
	var return_tween := get_tree().create_tween()
	return_tween.tween_property(self, "global_position", target_pos, slam_time * 3).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN_OUT)
	
	await return_tween.finished

	print(self.name, " : ", "Stand | Returning to Idle")
	state_chart.send_event("end_attack")
	state_chart.send_event("hand_finished")
