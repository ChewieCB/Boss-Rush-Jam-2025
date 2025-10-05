extends BossCore
class_name BlackjackHand


@onready var dust_particle: GPUParticles3D = $HandDust
@onready var death_particles: GPUParticles3D = $DeathDust
@onready var explosion_particle = $DeathExplosion


@export var controller_boss: BossBlackjack


## Attacks
# Hit
var slam_target: Vector3
@export var slam_time: float = 0.85
@export var hit_damage: float = 10


func _ready() -> void:
	super()


func fake_destroy() -> void:
	spawn_dust()
	spawn_explosion()
	sprite.visible = false
	debug_mesh.visible = false
	self.collision_layer = 0
	self.collision_mask = 0
	hurtbox.monitoring = false


func reinstate() -> void:
	self.collision_layer = pow(2, 3-1)
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


## PHASE LOGIC

func _on_hit_targeting_state_entered() -> void:
	debug_state_label.text = "Hit | Targeting"
	
	# Play a windup animation, track the player, and then launch the attack

	#anim_player.play("substack/idle")
	
	state_chart.send_event("start_targeting")
	state_chart.send_event("attack_buildup")
	
	# TODO - play windup anim (shake)
	#anim_player.play("substack/idle")
	await get_tree().create_timer(0.6).timeout
	_telegraph_attack("Hit")
	
	# Target the players position
	slam_target = target.global_position
	#draw_debug_sphere(slam_target, 2.0, Color.YELLOW)
	# TODO - raycast down to get floor y (reuse the bell AoE code)
	
	state_chart.send_event("hand_slam")


func _on_hit_slamming_state_entered() -> void:
	debug_state_label.text = "Hit | Slamming"
	
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
	state_chart.send_event("hand_finished")
	state_chart.send_event("end_attack")


func _on_hurtbox_body_entered(body: Node3D) -> void:
	if body is Player:
		body.health_component.damage(hit_damage)
		
