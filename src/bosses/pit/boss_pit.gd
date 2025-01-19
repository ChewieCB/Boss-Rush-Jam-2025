extends BossCore
class_name BossPit

@export var swipe_debug: CompressedTexture2D
@export var lunge_debug: CompressedTexture2D
@export var uppercut_debug: CompressedTexture2D

@export var FRICTION: float = 0.05
var lunge_friction: float = FRICTION

@onready var face_sprite: Sprite3D = $Sprite3D/FaceSprite
@onready var melee_attack_debug_mesh: MeshInstance3D = $Hurtbox/MeshInstance3D
@onready var anim_player: AnimationPlayer = $AnimationPlayer


func activate() -> void:
	super()
	state_chart.send_event("start_phase_1")


func _physics_process(delta: float) -> void:
	super(delta)
	debug_dist_label.text = str(self.global_position.distance_to(target.global_position))


func _on_hurtbox_body_entered(body: Node3D) -> void:
	pass
	#SoundManager.play_sound(TEMP_sfx_charge_impact)
	#if body == target:
		#target.health_component.damage(40)


func _on_movement_charging_state_entered() -> void:
	hurtbox.monitoring = true
	hurtbox.body_entered.connect(destroy_cover)

func destroy_cover(body: Node3D) -> void:
	if body is Cover:
		body.destroy()
		lunge_friction = FRICTION * 4
		hurtbox.monitoring = false

func _on_movement_charging_state_physics_processing(_delta: float) -> void:
	velocity.x = lerp(velocity.x, 0.0, lunge_friction)
	velocity.z = lerp(velocity.z, 0.0, lunge_friction)
	
	if hurtbox.monitoring:
		for body in hurtbox.get_overlapping_bodies():
			if body is Cover:
				destroy_cover(body)

	if velocity.x == 0 and velocity.z == 0:
		state_chart.send_event("end_charge")

func _on_movement_charging_state_exited() -> void:
	hurtbox.body_entered.disconnect(destroy_cover)
	lunge_friction = FRICTION
	hurtbox.monitoring = true


func _on_phase_1_melee_combo_targeting_state_entered() -> void:
	debug_state_label.text = "Melee Combo | Targeting"
	hurtbox.monitoring = true
	state_chart.send_event("start_moving")

func _on_phase_1_melee_combo_targeting_state_physics_processing(delta: float) -> void:
	if target in hurtbox.get_overlapping_bodies():
		state_chart.send_event("start_attack")
		state_chart.send_event("melee_attack")


func _on_phase_1_melee_combo_swipe_state_entered() -> void:
	debug_state_label.text = "Melee Combo | Swipe"
	
	face_sprite.texture = swipe_debug
	
	melee_attack_debug_mesh.visible = true
	state_chart.send_event("stop_moving")
	state_chart.send_event("start_targeting")
	#state_chart.send_event("stop_moving")
	anim_player.play("swipe")
	await anim_player.animation_finished
	face_sprite.texture = null
	#melee_attack_debug_mesh.visible = false
	# TODO - if player is in distance of lunge attack, lunge forwards
	if target in hurtbox.get_overlapping_bodies():
		state_chart.send_event("melee_attack")
	elif self.global_position.distance_to(target.global_position) < 40:
		state_chart.send_event("close_distance")
	else:
		state_chart.send_event("combo_end")


func _on_phase_1_melee_combo_hook_state_entered() -> void:
	debug_state_label.text = "Melee Combo | Hook"
	
	face_sprite.texture = swipe_debug
	
	melee_attack_debug_mesh.visible = true
	state_chart.send_event("stop_moving")
	state_chart.send_event("start_targeting")
	#state_chart.send_event("stop_moving")
	anim_player.play("hook")
	await anim_player.animation_finished
	face_sprite.texture = null
	#melee_attack_debug_mesh.visible = false
	# TODO - if player is in distance of lunge attack, lunge forwards
	if target in hurtbox.get_overlapping_bodies():
		state_chart.send_event("melee_attack")
	elif self.global_position.distance_to(target.global_position) < 40:
		state_chart.send_event("close_distance")
	else:
		state_chart.send_event("combo_end")


func damage_in_hurtbox(damage: float) -> void:
	if target in hurtbox.get_overlapping_bodies():
		target.health_component.damage(damage)


func _on_phase_1_melee_combo_lunge_state_entered() -> void:
	debug_state_label.text = "Melee Combo | Lunge"
	
	state_chart.send_event("stop_moving")
	state_chart.send_event("start_targeting")
	melee_attack_debug_mesh.visible = true
	#await get_tree().create_timer(0.5).timeout
	
	face_sprite.texture = lunge_debug
	anim_player.play("lunge")
	await $StateChart/Root/Movement/Charging.state_exited
	#await anim_player.animation_finished
	#state_chart.send_event("stop_moving")
	#state_chart.send_event("start_targeting")
	
	#await get_tree().create_timer(0.5).timeout
	face_sprite.texture = null
	#melee_attack_debug_mesh.visible = false
	#state_chart.send_event("start_targeting")
	#await get_tree().create_timer(0.5).timeout
	# TODO - if player is within range, uppercut them
	if target in hurtbox.get_overlapping_bodies():
		state_chart.send_event("melee_attack")
	else:
		state_chart.send_event("combo_end")


func lunge() -> void:
	var charge_dir = -self.global_basis.z
	var charge_impulse = self.global_position.distance_to(target.global_position) * 4
	velocity += charge_dir * charge_impulse
	state_chart.send_event("start_charge")


func _on_phase_1_melee_combo_uppercut_state_entered() -> void:
	debug_state_label.text = "Melee Combo | Uppercut"
	
	#melee_attack_debug_mesh.visible = true
	state_chart.send_event("stop_moving")
	state_chart.send_event("start_targeting")
	#await get_tree().create_timer(0.6).timeout
	
	state_chart.send_event("stop_moving")
	face_sprite.texture = uppercut_debug
	anim_player.play("uppercut")
	await anim_player.animation_finished
	
	if target in hurtbox.get_overlapping_bodies():
		target.health_component.damage(10)
		target.velocity = Vector3.ZERO
		target.vel_vertical += 25.0
	
	#await get_tree().create_timer(0.5).timeout
	face_sprite.texture = null
	#melee_attack_debug_mesh.visible = false
	# TODO - jump up to meet the player and slam them down
	var horizontal_distance = Vector2(
		self.global_position.x, 
		self.global_position.z
	).distance_to(Vector2(
		target.global_position.x,
		target.global_position.z
	))
	if horizontal_distance < 20:
		state_chart.send_event("melee_attack")
	else:
		state_chart.send_event("combo_end")


func uppercut(damage: float, uppercut_force: float) -> void:
	if target in hurtbox.get_overlapping_bodies():
		target.health_component.damage(damage)
		target.velocity = Vector3.ZERO
		target.vel_vertical += uppercut_force


func _on_phase_1_melee_combo_air_slam_state_entered() -> void:
	debug_state_label.text = "Melee Combo | Air Slam"
	
	#melee_attack_debug_mesh.visible = true
	state_chart.send_event("stop_moving")
	state_chart.send_event("start_targeting")
	#await get_tree().create_timer(0.6).timeout
	
	state_chart.send_event("stop_moving")
	face_sprite.texture = uppercut_debug
	anim_player.play("air_slam")
	await anim_player.animation_finished
	
	if target in hurtbox.get_overlapping_bodies():
		target.health_component.damage(10)
		target.velocity = Vector3.ZERO
		target.vel_vertical += 25.0
	
	#await get_tree().create_timer(0.5).timeout
	face_sprite.texture = null
	#melee_attack_debug_mesh.visible = false
	# TODO - jump up to meet the player and slam them down
	#if target in hurtbox.get_overlapping_bodies():
		#state_chart.send_event("melee_attack")
	#else:
	state_chart.send_event("combo_end")
	pass # Replace with function body.


func air_slam_jump(jump_force: float) -> void:
	self.velocity.y += jump_force


func _on_phase_1_melee_combo_recover_state_entered() -> void:
	debug_state_label.text = "Melee Combo | Recovery"
	#hurtbox.monitoring = false
	state_chart.send_event("stop_moving")
	await get_tree().create_timer(attack_recovery_time).timeout
	state_chart.send_event("end_recovery")
