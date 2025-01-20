extends BossCore
class_name BossPit

@export var swipe_debug: CompressedTexture2D
@export var lunge_debug: CompressedTexture2D
@export var uppercut_debug: CompressedTexture2D

@export var FRICTION: float = 0.05
var lunge_friction: float = FRICTION
@export var lunge_force: float = 7.50

@export var AIR_SLAM_DROP: float = 35.0
var air_slam_drop: float = AIR_SLAM_DROP

@export var wave_material: ShaderMaterial

var turret_spawns: Array = []:
	set(value):
		turret_spawns = value
		valid_spawns = turret_spawns.duplicate()
var valid_spawns: Array

@onready var face_sprite: Sprite3D = $Sprite3D/FaceSprite
@onready var melee_attack_debug_mesh: MeshInstance3D = $Hurtbox/MeshInstance3D
@onready var anim_player: AnimationPlayer = $AnimationPlayer


func activate() -> void:
	super()
	state_chart.send_event("start_phase_1")
	spawn_turrets(1)


func _physics_process(delta: float) -> void:
	super(delta)
	debug_dist_label.text = str(self.global_position.distance_to(target.global_position))



func select_attack_phase_1() -> void:
	var dist_to_target = self.global_position.distance_to(target.global_position)
	var possible_phases = [
		"start_melee_combo_attack",
		"start_close_distance_attack_close",
		"start_close_distance_attack_far",
	]
	
	if dist_to_target > 10:
		state_chart.send_event("start_close_distance_attack_close")
	elif dist_to_target > 20:
		state_chart.send_event("start_close_distance_attack_far")
	else:
		state_chart.send_event("start_melee_combo_attack")


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
		hurtbox.set_deferred("monitoring", false)

func _on_movement_charging_state_physics_processing(_delta: float) -> void:
	velocity.x = lerp(velocity.x, 0.0, lunge_friction)
	velocity.z = lerp(velocity.z, 0.0, lunge_friction)
	
	if hurtbox.monitoring:
		for body in hurtbox.get_overlapping_bodies():
			if body is Cover:
				destroy_cover(body)
			elif body == target:
				damage_in_hurtbox(0.0, true)

	if velocity.x == 0 and velocity.z == 0:
		state_chart.send_event("end_charge")

func _on_movement_charging_state_exited() -> void:
	hurtbox.body_entered.disconnect(destroy_cover)
	lunge_friction = FRICTION
	hurtbox.set_deferred("monitoring", true)

#####

func spawn_turrets(count: int) -> void:
	for i in count:
		if valid_spawns.size() > 0:
			var spawn_idx: int = randi_range(0, valid_spawns.size() - 1)
			var spawn: TurretSpawnPoint = valid_spawns.pop_at(spawn_idx)
			var turret = spawn.spawn_turret(target)
			turret.health_component.died.connect(_on_turret_destroyed)

func _on_turret_destroyed(turret: PitTurret) -> void:
	var turret_spawn = turret.get_parent()
	valid_spawns.push_back(turret_spawn)

#######

func _on_phase_1_state_entered() -> void:
	#debug_phase_label.text = "Phase 1"
	current_phase = 1
	state_chart.send_event("start_close_distance_attack_far")


func _on_phase_1_melee_combo_targeting_state_entered() -> void:
	debug_state_label.text = "Melee Combo | Targeting"
	hurtbox.set_deferred("monitoring", true)
	state_chart.send_event("start_moving")

func _on_phase_1_melee_combo_targeting_state_physics_processing(delta: float) -> void:
	if target in hurtbox.get_overlapping_bodies():
		state_chart.send_event("start_attack")
		#state_chart.send_event("melee_attack")
	elif self.global_position.distance_to(target.global_position) > 22:
		select_attack()


func _on_phase_1_melee_combo_swipe_state_entered() -> void:
	debug_state_label.text = "Melee Combo | Swipe"
	
	face_sprite.texture = swipe_debug
	
	#melee_attack_debug_mesh.visible = true
	state_chart.send_event("start_targeting")
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
	
	#melee_attack_debug_mesh.visible = true
	state_chart.send_event("start_targeting")
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


func damage_in_hurtbox(damage: float, stun: bool = false) -> void:
	if target in hurtbox.get_overlapping_bodies():
		target.health_component.damage(damage)
		if stun:
			target.stun(1.2)


func _on_phase_1_melee_combo_lunge_state_entered() -> void:
	debug_state_label.text = "Melee Combo | Lunge"
	
	state_chart.send_event("start_targeting")
	
	face_sprite.texture = lunge_debug
	anim_player.play("lunge")
	await $StateChart/Root/Movement/Charging.state_exited
	state_chart.send_event("stop_moving")

	face_sprite.texture = null
	
	if target in hurtbox.get_overlapping_bodies():
		state_chart.send_event("melee_attack")
	else:
		state_chart.send_event("combo_end")

func lunge() -> void:
	var charge_dir = -self.global_basis.z
	var charge_impulse = self.global_position.distance_to(target.global_position) * lunge_force
	velocity += charge_dir * charge_impulse
	state_chart.send_event("start_charge")


func _on_phase_1_melee_combo_uppercut_state_entered() -> void:
	debug_state_label.text = "Melee Combo | Uppercut"
	
	state_chart.send_event("start_targeting")
	
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
	
	state_chart.send_event("start_targeting")
	
	face_sprite.texture = uppercut_debug
	anim_player.play("air_slam")
	await anim_player.animation_finished
	
	hurtbox.body_entered.connect(_air_slam_damage)
	
	anim_player.play("air_slam_attack")
	await anim_player.animation_finished
	
	face_sprite.texture = null

func _on_phase_1_melee_combo_air_slam_state_physics_processing(delta: float) -> void:
	#velocity.x = lerp(velocity.x, 0.0, lunge_friction)
	#velocity.z = lerp(velocity.z, 0.0, lunge_friction)
	if anim_player.is_playing():
		await anim_player.animation_finished
	
	if is_on_floor():
		#state_chart.send_event("combo_end")
		state_chart.send_event("aoe_burst")
		state_chart.send_event("stop_moving")

func air_slam_jump(jump_force: float) -> void:
	state_chart.send_event("stop_moving")
	self.velocity += self.global_basis.z * 5.5
	vel_vertical += jump_force
	state_chart.send_event("start_targeting")

func air_slam_attack(damage: float, slam_force: float, target_pos: Vector3 = target.global_position) -> void:
	var charge_dir = self.global_position.direction_to(target_pos)
	var charge_impulse = self.global_position.distance_to(target_pos) * 2
	velocity += charge_dir * charge_impulse
	vel_vertical -= air_slam_drop

func _air_slam_damage(body: Node3D) -> void:
	if body == target:
		body.health_component.damage(15)
		body.velocity = Vector3.ZERO
		body.vel_vertical -= 65.0
		hurtbox.set_deferred("monitoring", false)
		hurtbox.body_entered.disconnect(_air_slam_damage)


func _on_melee_combo_ground_pound_state_entered() -> void:
	debug_state_label.text = "Melee Combo | Ground Pound"
	state_chart.send_event("stop_moving")
	velocity = Vector3.ZERO
	var wave_callback: Callable = func(): 
		state_chart.send_event("combo_end")
	spawn_center_wave(10.0, 0.8, 2.0, false, wave_callback)


func _on_phase_1_melee_combo_recover_state_entered() -> void:
	debug_state_label.text = "Melee Combo | Recovery"
	#hurtbox.monitoring = false
	state_chart.send_event("stop_moving")
	await get_tree().create_timer(attack_recovery_time).timeout
	hurtbox.set_deferred("monitoring", true)
	select_attack()
	state_chart.send_event("end_recovery")


# TODO - rework and clean this up for the slam 
func spawn_center_wave(
	max_radius: float, 
	spawned_wave_time: float = 1.0, 
	spawned_wave_height: float = 4.0, 
	telegraph: bool = false,
	callback: Callable = func(): pass
) -> void:
	var area_pos: Vector3 = self.global_position
	#area_pos.y -= spawned_wave_height
	
	# Generate a collider
	var area_collider := Area3D.new()
	var area_collider_shape := CollisionShape3D.new()
	var collider_shape := CylinderShape3D.new()
	collider_shape.radius = 0.01
	collider_shape.height = spawned_wave_height
	area_collider_shape.shape = collider_shape
	area_collider.add_child(area_collider_shape)
	area_collider.collision_layer = 0
	area_collider.collision_mask = pow(2, 1-1) + pow(2, 2-1)  # Player
	area_collider.monitoring = true
	
	get_tree().get_root().add_child(area_collider)
	
	area_collider.global_position = area_pos
	area_collider.body_entered.connect(_on_wave_collision)
	area_collider.body_entered.connect(area_collider.queue_free)
	
	var debug_mesh_instance = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	
	spawned_area_objects.append([area_collider, debug_mesh_instance])
	
	# Generate a visual
	get_tree().get_root().add_child(debug_mesh_instance)
	
	debug_mesh_instance.mesh = mesh
	debug_mesh_instance.cast_shadow = false
	debug_mesh_instance.global_position = area_pos
	
	mesh.bottom_radius = 0.0
	mesh.top_radius = 0.0
	mesh.height = spawned_wave_height
	mesh.material = wave_material
	
	#if telegraph:
		#var telegraph_tween = get_tree().create_tween()
		#var mesh_color: Color = debug_mesh_instance.mesh.material.get("shader_parameter/color")
		#
		#telegraph_tween.tween_property(debug_mesh_instance, "mesh:bottom_radius", 6.0, telegraph_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CIRC)
		#telegraph_tween.parallel().tween_property(debug_mesh_instance, "mesh:top_radius", 6.0, telegraph_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CIRC)
		##telegraph_tween.parallel().tween_method(material_glow.bind(debug_mesh_instance.mesh.material, Color.RED), 0, 1, telegraph_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CIRC)
		#telegraph_tween.parallel().tween_callback(func(): state_chart.send_event("attack_telegraph")).set_delay(0)
		#telegraph_tween.chain().tween_property(debug_mesh_instance, "mesh:bottom_radius", 1.0, telegraph_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		#telegraph_tween.parallel().tween_property(debug_mesh_instance, "mesh:top_radius", 1.0, telegraph_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		##telegraph_tween.parallel().tween_method(material_glow.bind(debug_mesh_instance.mesh.material, mesh_color), 0, 1, telegraph_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		#
		#await telegraph_tween.finished
	
	state_chart.send_event("attack_start")
	var wave_attack_callback: Callable = func():
		state_chart.send_event("finish_wave")
	
	# Animate the visual
	SoundManager.play_sound(TEMP_sfx_area_1)
	var tween = get_tree().create_tween()
	tween.tween_property(mesh, "bottom_radius", max_radius, spawned_wave_time)
	tween.parallel().tween_property(mesh, "top_radius", max_radius, spawned_wave_time)
	tween.parallel().tween_property(area_collider_shape.shape, "radius", max_radius, spawned_wave_time)
	tween.tween_callback(func():
		debug_mesh_instance.queue_free()
		area_collider.queue_free()
	)
	tween.tween_callback(callback)


func _on_wave_collision(body: Node3D) -> void:
	if body == target:
		body.health_component.damage(10)
	elif body is Cover:
		destroy_cover(body)


func _on_air_slam_targeting_state_entered() -> void:
	debug_state_label.text = "Air Slam | Targeting"
	hurtbox.set_deferred("monitoring", true)
	state_chart.send_event("start_targeting")
	await get_tree().create_timer(1.0).timeout
	state_chart.send_event("start_attack")


func _on_air_slam_state_entered() -> void:
	air_slam_drop = AIR_SLAM_DROP * 0.7


func _on_air_slam_state_exited() -> void:
	air_slam_drop = AIR_SLAM_DROP



func _on_phase_1_lunge_targeting_state_entered() -> void:
	debug_state_label.text = "Lunge | Targeting"
	hurtbox.set_deferred("monitoring", true)
	state_chart.send_event("start_moving")
	state_chart.send_event("close_distance")

func _on_phase_1_lunge_state_entered() -> void:
	debug_state_label.text = "Lunge | Attack"
	
	state_chart.send_event("start_targeting")
	
	face_sprite.texture = lunge_debug
	anim_player.play("lunge")
	await $StateChart/Root/Movement/Charging.state_exited
	state_chart.send_event("stop_moving")

	face_sprite.texture = null
	state_chart.send_event("combo_end")

func _on_phase_1_lunge_recover_state_entered() -> void:
	debug_state_label.text = "Lunge | Recovery"
	#hurtbox.monitoring = false
	state_chart.send_event("stop_moving")
	await get_tree().create_timer(attack_recovery_time).timeout
	hurtbox.set_deferred("monitoring", true)
	select_attack()
	state_chart.send_event("end_recovery")
