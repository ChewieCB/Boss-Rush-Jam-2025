extends BossCore
class_name BossPit

@export var swipe_debug: CompressedTexture2D
@export var lunge_debug: CompressedTexture2D
@export var uppercut_debug: CompressedTexture2D

@onready var face_sprite: Sprite3D = $Sprite3D/FaceSprite
@onready var melee_attack_debug_mesh: MeshInstance3D = $Hurtbox/MeshInstance3D


func _ready() -> void:
	super()
	await get_tree().physics_frame
	state_chart.send_event("start_phase_1")


func _on_hurtbox_body_entered(body: Node3D) -> void:
	pass
	#SoundManager.play_sound(TEMP_sfx_charge_impact)
	#if body == target:
		#target.health_component.damage(40)


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
	
	face_sprite.visible = true
	face_sprite.texture = swipe_debug
	
	melee_attack_debug_mesh.visible = true
	state_chart.send_event("start_targeting")
	await get_tree().create_timer(0.4).timeout
	
	state_chart.send_event("stop_moving")
	if target in hurtbox.get_overlapping_bodies():
		target.health_component.damage(10)
	
	await get_tree().create_timer(0.5).timeout
	melee_attack_debug_mesh.visible = false
	face_sprite.visible = false
	# TODO - if player is in distance of lunge attack, lunge forwards
	if self.global_position.distance_to(target.global_position) < 20:
		state_chart.send_event("melee_attack")
	else:
		state_chart.send_event("combo_end")


func _on_phase_1_melee_combo_lunge_state_entered() -> void:
	debug_state_label.text = "Melee Combo | Lunge"
	
	face_sprite.visible = false
	
	state_chart.send_event("start_targeting")
	melee_attack_debug_mesh.visible = true
	await get_tree().create_timer(1.0).timeout
	
	face_sprite.visible = true
	face_sprite.texture = lunge_debug
	state_chart.send_event("start_charge")
	await get_tree().create_timer(0.4).timeout
	state_chart.send_event("stop_moving")
	if target in hurtbox.get_overlapping_bodies():
		target.health_component.damage(15)
	
	await get_tree().create_timer(0.5).timeout
	melee_attack_debug_mesh.visible = false
	state_chart.send_event("start_targeting")
	await get_tree().create_timer(0.5).timeout
	# TODO - if player is within range, uppercut them
	if target in hurtbox.get_overlapping_bodies():
		state_chart.send_event("melee_attack")
	else:
		state_chart.send_event("combo_end")


func _on_phase_1_melee_combo_uppercut_state_entered() -> void:
	debug_state_label.text = "Melee Combo | Uppercut"
	
	face_sprite.visible = false
	
	melee_attack_debug_mesh.visible = true
	state_chart.send_event("start_targeting")
	await get_tree().create_timer(0.6).timeout
	
	state_chart.send_event("stop_moving")
	face_sprite.visible = true
	face_sprite.texture = uppercut_debug
	if target in hurtbox.get_overlapping_bodies():
		target.health_component.damage(10)
		target.velocity = Vector3.ZERO
		target.vel_vertical += 25.0
	
	await get_tree().create_timer(0.5).timeout
	melee_attack_debug_mesh.visible = false
	face_sprite.visible = false
	# TODO - jump up to meet the player and slam them down
	#if target in hurtbox.get_overlapping_bodies():
		#state_chart.send_event("melee_attack")
	#else:
	state_chart.send_event("combo_end")


func _on_phase_1_melee_combo_recover_state_entered() -> void:
	debug_state_label.text = "Melee Combo | Recovery"
	hurtbox.monitoring = false
	await get_tree().create_timer(attack_recovery_time).timeout
	state_chart.send_event("end_recovery")
