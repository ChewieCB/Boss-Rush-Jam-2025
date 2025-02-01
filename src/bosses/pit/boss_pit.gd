extends BossCore
class_name BossPit

signal charge_ended

enum Stance {DEFENSIVE, AGGRESSIVE}

@export_category("Display")
@export var swipe_sprite: CompressedTexture2D
@export var hook_sprite: CompressedTexture2D
@export var lunge_sprite: CompressedTexture2D
@export var uppercut_sprite: CompressedTexture2D
@export var slam_sprite: CompressedTexture2D

@export var wave_material: ShaderMaterial

@export_category("Movement")
@export var wave_amplitude: float = 7.0
@export var wave_frequency: float = 5.0
@export var time_elapsed: float = 0.0

@export_category("Phases")
@export var surveillance_boss: BossSurveillance 
var phase_stance: Stance = Stance.AGGRESSIVE:
	set(value):
		phase_stance = value
		if phase_stance == Stance.AGGRESSIVE:
			state_chart.send_event("aggressive_stance")
		elif phase_stance == Stance.DEFENSIVE:
			state_chart.send_event("defensive_stance")
		phase_debug_label.text = "Phase %s (%s)" % [current_phase, Stance.keys()[phase_stance]]

@export_group("Attacks")
@onready var hurtbox_collider: CollisionShape3D = $Hurtbox/CollisionShape3D
@export var hurtbox_range_close: float = 3.5
@export var hurtbox_range_far: float = 4.5
@export_subgroup("Swipe")
@export var swipe_damage: float = 7.0
@export_subgroup("Hook")
@export var hook_damage: float = 8.0
@export_subgroup("Uppercut")
@export var uppercut_damage: float = 5.0
@export_subgroup("Air Slam")
#@export var air_slam_jump_force: float = 50.0
#@export var air_slam_jump_height: float = 20.0
@export var air_slam_damage: float = 15.0
var slam_target_pos := Vector3.ZERO
@export var air_slam_cooldown: float = 15.0
@onready var air_slam_timer: Timer = $AirSlamCooldown
@export_subgroup("Ground Pound")
@export var ground_pound_wave_radius: float = 16.0
@export var ground_wave_damage: float = 6.0
@export_subgroup("Lunge")
@export var lunge_friction: float = 0.05
@export var lunge_damage: float = 5.0
@export var lunge_force: float = 6.5
@export var lunge_cooldown: float = 15.0
@onready var lunge_timer: Timer = $LungeCooldown

@onready var phase_debug_label: Label3D = $DebugPhaseLabel
@onready var melee_attack_debug_mesh: MeshInstance3D = $Hurtbox/MeshInstance3D
@onready var anim_player: AnimationPlayer = $AnimationPlayer

@export var shield_radius: float = 4.0
@onready var shield_body: StaticBody3D = $Shield
@onready var shield_mesh_solid: MeshInstance3D = $Shield/ShieldMeshSolid
@onready var shield_mesh_wispy: MeshInstance3D = $Shield/ShieldMeshWispy
@onready var shield_collider: CollisionShape3D = $Shield/CollisionShape3D
var shield_tween: Tween


func _ready() -> void:
	super()
	hurtbox_collider.shape.size.z = hurtbox_range_close


func activate() -> void:
	super()
	state_chart.send_event("intro_slam")


func toggle_stance() -> void:
	if phase_stance == Stance.AGGRESSIVE:
		phase_stance = Stance.DEFENSIVE
	elif phase_stance == Stance.DEFENSIVE:
		phase_stance = Stance.AGGRESSIVE


func show_shield() -> void:
	if shield_tween:
		shield_tween.kill()
	
	shield_tween = get_tree().create_tween()
	shield_tween.tween_property(shield_mesh_solid.mesh, "radius", shield_radius, 0.6)
	shield_tween.parallel().tween_property(shield_mesh_solid.mesh, "height", shield_radius * 2, 0.6)
	shield_tween.parallel().tween_property(shield_mesh_wispy.mesh, "radius", shield_radius, 0.6)
	shield_tween.parallel().tween_property(shield_mesh_wispy.mesh, "height", shield_radius * 2, 0.6)
	shield_tween.tween_callback(shield_collider.set_disabled.bind(false))


func hide_shield() -> void:
	if shield_tween:
		shield_tween.kill()
	
	shield_tween = get_tree().create_tween()
	shield_tween.tween_property(shield_mesh_solid.mesh, "radius", 0, 0.6)
	shield_tween.parallel().tween_property(shield_mesh_solid.mesh, "height", 0, 0.6)
	shield_tween.parallel().tween_property(shield_mesh_wispy.mesh, "radius", 0, 0.6)
	shield_tween.parallel().tween_property(shield_mesh_wispy.mesh, "height", 0, 0.6)
	shield_tween.tween_callback(shield_collider.set_disabled.bind(true))


func _physics_process(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	time_elapsed += delta
	var chase_direction: Vector3 = self.global_position.direction_to(target.global_position)
	var perpendicular: Vector3 = chase_direction.rotated(Vector3.UP, PI/2)
	var wave_offset = perpendicular * sin(time_elapsed * wave_frequency) * wave_amplitude
	var desired_position = target.global_position + wave_offset
	navigation_component.set_nav_target_position(desired_position)
	move_and_slide()
	
	debug_dist_label.text = str(self.global_position.distance_to(target.global_position))


func select_attack() -> void:
	match current_phase:
		1:
			select_attack_phase_1()
		2:
			select_attack_phase_2()
		3:
			select_attack_phase_3()
		_:
			push_error("Invalid phase %s" % current_phase)


func select_attack_phase_1() -> void:
	var dist_to_target = self.global_position.distance_to(target.global_position)
	var _possible_phases = [
		"start_melee_combo_attack",
		"start_close_distance_attack_close",
	]
	
	if dist_to_target > 10 and lunge_timer.is_stopped():
		state_chart.send_event("start_close_distance_attack_close")
	else:
		state_chart.send_event("start_melee_combo_attack")


func select_attack_phase_2() -> void:
	var dist_to_target = self.global_position.distance_to(target.global_position)
	var _possible_phases = [
		"start_melee_combo_attack",
		"start_close_distance_attack_close",
		"start_close_distance_attack_far",
	]
	
	# TODO - rework this if we have more defensive abilities
	if phase_stance == Stance.DEFENSIVE:
		return
	
	if dist_to_target > 22 and air_slam_timer.is_stopped():
		state_chart.send_event("start_close_distance_attack_far")
	elif dist_to_target > 7 and lunge_timer.is_stopped():
		state_chart.send_event("start_close_distance_attack_close")
	else:
		state_chart.send_event("start_melee_combo_attack")


func select_attack_phase_3() -> void:
	var dist_to_target = self.global_position.distance_to(target.global_position)
	var _possible_phases = [
		"start_melee_combo_attack",
		"start_hammer_ground_attack",
		"start_close_distance_attack_close",
		"start_close_distance_attack_far",
	]
	
	if dist_to_target > 14 and air_slam_timer.is_stopped():
		state_chart.send_event("start_close_distance_attack_far")
	elif dist_to_target > 5 and lunge_timer.is_stopped():
		state_chart.send_event("start_close_distance_attack_close")
	else:
		if randf() < 0.3 and dist_to_target < 10.0:
			state_chart.send_event("start_melee_start_hammer_ground_attack")
		else:
			state_chart.send_event("start_melee_combo_attack")


## ======== Signal Callback Methods ========

func _on_died() -> void:
	state_chart.send_event("death")
	state_chart.send_event("stop_moving")
	state_chart.send_event("deactivate")


func _exit_tree() -> void:
	if shield_mesh_solid.mesh.radius > 0.1:
		hide_shield()


func _on_hurtbox_body_entered(_body: Node3D) -> void:
	pass
	#SoundManager.play_sound(TEMP_sfx_charge_impact)
	#if body == target:
		#target.health_component.damage(40)


## ======== State Chart Methods ========


func _on_movement_charging_state_entered() -> void:
	hurtbox.set_deferred("monitoring", true)
	hurtbox.body_entered.connect(destroy_cover)

func destroy_cover(body: Node3D) -> void:
	if body is Cover:
		body.destroy()
		hurtbox.set_deferred("monitoring", false)

func _on_movement_charging_state_physics_processing(_delta: float) -> void:
	velocity.x = lerp(velocity.x, 0.0, lunge_friction)
	velocity.z = lerp(velocity.z, 0.0, lunge_friction)
	
	# TODO - find a better way to do this
	if hurtbox.monitoring:
		for body in hurtbox.get_overlapping_bodies():
			if body is Cover:
				destroy_cover(body)
			elif body == target:
				damage_in_hurtbox(lunge_damage)
				hurtbox.set_deferred("monitoring", false)
				velocity.x = 0
				velocity.z = 0
				#print("Velocity halted due to collision: %s" % velocity)
				state_chart.send_event("end_charge")
				return
	
	if abs(velocity.x) < 0.1 and abs(velocity.z) < 0.1:
		velocity.x = 0
		velocity.z = 0
		#print("Velocity halted due to friction: %s" % velocity)
		state_chart.send_event("end_charge")

func _on_movement_charging_state_exited() -> void:
	charge_ended.emit()
	hurtbox.body_entered.disconnect(destroy_cover)
	hurtbox.set_deferred("monitoring", true)

### ATTACK PHASES --------------------------------

func damage_in_hurtbox(damage: float, stun: bool = false) -> void:
	if target in hurtbox.get_overlapping_bodies():
		target.health_component.damage(damage)
		if stun:
			target.stun(1.2)


func swipe() -> void:
	target.health_component.damage(swipe_damage)


func hook() -> void:
	target.health_component.damage(hook_damage)


func uppercut(uppercut_force: float) -> void:
	if target in hurtbox.get_overlapping_bodies():
		target.health_component.damage(uppercut_damage)
		target.velocity = Vector3.ZERO
		target.vel_vertical += uppercut_force
		var xz_force := Vector2(-self.global_basis.z.x, -self.global_basis.z.z)
		target.vel_horizontal += xz_force * 11.0


func lunge() -> void:
	#print("Lunge function entered")
	var charge_dir = -self.global_basis.z
	var charge_impulse = max(self.global_position.distance_to(target.global_position), 1) * lunge_force
	velocity += charge_dir * charge_impulse
	#print("Lunged with vector: %s, velocity = %s" % [charge_impulse, velocity])
	state_chart.send_event("start_charge")


#### INTRO AIR SLAM ==========================

func _on_intro_air_slam_recover_state_entered() -> void:
	debug_state_label.text = "Intro Slam | Recovery"
	
	state_chart.send_event("stop_moving")
	slam_target_pos = target.global_position
	anim_player.play("RESET")
	await get_tree().create_timer(attack_recovery_time).timeout
	
	state_chart.send_event("end_recovery")
	select_attack()

#### PHASE 1 ==========================
# Basic Combo
# Lunge
func _on_phase_1_state_entered() -> void:
	current_phase = 1
	phase_debug_label.text = "Phase 1"
	state_chart.send_event("intro_slam")


#### Phase 1 | Melee Combo (Basic)
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
	
	anim_player.play("swipe")
	await anim_player.animation_finished
	
	hurtbox_collider.shape.size.z = hurtbox_range_far
	
	if target in hurtbox.get_overlapping_bodies():
		state_chart.send_event("melee_attack")
	# Phase 2 - if player is in distance of lunge attack, lunge forwards
	elif self.global_position.distance_to(target.global_position) < 20 and current_phase > 1:
		state_chart.send_event("close_distance")
	else:
		state_chart.send_event("combo_end")


# HOOK
func _on_melee_combo_hook_state_entered() -> void:
	debug_state_label.text = "Melee Combo | Hook"
	hurtbox.set_deferred("monitoring", true)
	
	state_chart.send_event("start_targeting")
	
	anim_player.play("hook")
	await anim_player.animation_finished
	
	if current_phase > 1:
		if target in hurtbox.get_overlapping_bodies():
			state_chart.send_event("melee_attack")
			return
		# Phase 2 - if player is in distance of lunge attack, lunge forwards
		elif self.global_position.distance_to(target.global_position) < 20:
			state_chart.send_event("close_distance")
			return
	state_chart.send_event("combo_end")


 # UPPERCUT
func _on_melee_combo_uppercut_state_entered() -> void:
	debug_state_label.text = "Melee Combo | Uppercut"
	hurtbox.set_deferred("monitoring", true)
	
	state_chart.send_event("start_targeting")
	
	anim_player.play("uppercut")
	await anim_player.animation_finished
	
	# Phase 2 - Uppercut chaser movement
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


# RECOVERY
func _on_melee_combo_recover_state_entered() -> void:
	debug_state_label.text = "Melee Combo | Recovery"
	
	hurtbox_collider.shape.size.z = hurtbox_range_close
	state_chart.send_event("stop_moving")
	await get_tree().create_timer(attack_recovery_time).timeout
	anim_player.play("RESET")
	
	select_attack()
	state_chart.send_event("end_recovery")


#### Phase 1-3 | Lunge Closer
func _on_lunge_closer_targeting_state_entered() -> void:
	debug_state_label.text = "Lunge | Targeting"
	hurtbox.set_deferred("monitoring", true)
	
	state_chart.send_event("start_moving")
	state_chart.send_event("close_distance")


func _on_lunge_closer_attack_state_entered() -> void:
	debug_state_label.text = "Lunge | Attack"
	
	state_chart.send_event("start_targeting")
	
	if $StateChart/Root/Movement/Charging.active:
		#print("Waiting for current charge to finish")
		await charge_ended
	if anim_player.is_playing():
		#print("Waiting for anim player to finish")
		await anim_player.animation_finished
	#print("Lunge animation playing")
	anim_player.play("lunge")
	
	await charge_ended
	#print("Charge ended")

	state_chart.send_event("stop_moving")
	state_chart.send_event("combo_end")


func _on_lunge_closer_recover_state_entered() -> void:
	debug_state_label.text = "Lunge | Recovery"
	#print("Lunge ended - recovering")
	state_chart.send_event("stop_moving")
	await get_tree().create_timer(attack_recovery_time).timeout
	
	lunge_timer.start(lunge_cooldown)
	select_attack()
	state_chart.send_event("end_recovery")


#### PHASE 2 ==========================

func _on_phase_2_state_entered() -> void:
	current_phase = 2
	phase_debug_label.text = "Phase 2"
	lunge_timer.wait_time *= 0.7
	toggle_stance()

#### Phase 2 | Combo Lunge
func _on_melee_combo_lunge_state_entered() -> void:
	debug_state_label.text = "Melee Combo | Lunge"
	hurtbox.set_deferred("monitoring", true)
	
	state_chart.send_event("start_targeting")
	
	if $StateChart/Root/Movement/Charging.active:
		#print("Waiting for current charge to finish")
		await charge_ended
	if anim_player.is_playing():
		#print("Waiting for anim player to finish")
		await anim_player.animation_finished
	#print("Lunge animation playing")
	anim_player.play("lunge")
	
	await charge_ended
	#print("Charge ended")

	state_chart.send_event("stop_moving")
	
	if target in hurtbox.get_overlapping_bodies():
		state_chart.send_event("melee_attack")
	else:
		state_chart.send_event("combo_end")


#### Air Slam

func air_slam_trajectory(goal_pos: Vector3 = Vector3.ZERO, debug: bool = false) -> Vector3:
	var start_pos = self.global_position
	var highest_y = max(start_pos.y, goal_pos.y)
	var jump_height = surveillance_boss.global_position.y - 12.0 - 2.0
	var apex_y = highest_y + jump_height
	apex_y = clamp(apex_y, 0, surveillance_boss.global_position.y - 1.0 - start_pos.y)
	
	var velocity_v: float = sqrt( 
		2 * GRAVITY * (apex_y - start_pos.y)
	)
	
	# TODO - make time_up and time_down configurable so we can set a jump time
	var time_up: float = velocity_v / GRAVITY
	var time_down: float = sqrt(2.0 * (apex_y - goal_pos.y) / GRAVITY)
	var time: float = time_up + time_down
	
	var displacement_xz: Vector2 = Vector2(goal_pos.x, goal_pos.z) - Vector2(start_pos.x, start_pos.z)
	var horizontal_distance: float = displacement_xz.length()
	var velocity_h = horizontal_distance / time
	var horizontal_dir: Vector2 = displacement_xz.normalized()
	
	var initial_velocity := Vector3(
		horizontal_dir.x * velocity_h,
		velocity_v,
		horizontal_dir.y * velocity_h,
	)
	
	# Drawing
	if debug:
		var trajectory_points: Array = []
		
		for i in range(1, 151):
			var t = time * float(i) / float(151)
			var x = start_pos.x + initial_velocity.x * t
			var y = start_pos.y + initial_velocity.y * t - 0.5 * GRAVITY * t * t
			var z = start_pos.z + initial_velocity.z * t
			trajectory_points.append(Vector3(x, y, z))
		
		debug_trajectory_mesh.mesh.clear_surfaces()
		debug_trajectory_mesh.mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for p in trajectory_points:
			debug_trajectory_mesh.mesh.surface_set_color(Color.RED)
			debug_trajectory_mesh.mesh.surface_add_vertex(p)
		debug_trajectory_mesh.mesh.surface_end()
		
	return initial_velocity


func air_slam_jump(debug: bool = false, goal_position: Vector3 = target.global_position + self.global_basis.z * 0.5) -> void:
	state_chart.send_event("start_jumping")
	self.velocity = air_slam_trajectory(goal_position, debug)

func air_slam_attack(slam_force: float, _target_pos: Vector3 = slam_target_pos) -> void:
	# TODO - replace this with a properly configurable trajectory
	target.health_component.damage(air_slam_damage)
	target.vel_vertical -= slam_force
	self.vel_vertical -= slam_force

func _air_slam_damage(body: Node3D) -> void:
	if body == target:
		hurtbox.set_deferred("monitoring", false)
		target.velocity = Vector3.ZERO
		self.velocity = Vector3.ZERO
		anim_player.play("air_slam_attack")
		hurtbox.body_entered.disconnect(_air_slam_damage)


func _on_intro_air_slam_state_entered() -> void:
	debug_state_label.text = "Intro Air Slam"
	
	hurtbox.set_deferred("monitoring", false)
	state_chart.send_event("start_targeting")
	
	anim_player.play("air_slam_intro")
	await anim_player.animation_finished
	
	hurtbox.body_entered.connect(_air_slam_damage)


func _on_air_slam_state_entered() -> void:
	debug_state_label.text = "Air Slam"
	
	state_chart.send_event("start_targeting")
	
	anim_player.play("air_slam")
	hurtbox.body_entered.connect(_air_slam_damage)
	hurtbox.set_deferred("monitoring", true)
	await anim_player.animation_finished


func _on_air_slam_state_physics_processing(_delta: float) -> void:
	if anim_player.is_playing():
		await anim_player.animation_finished
	
	if is_on_floor():
		#state_chart.send_event("combo_end")
		state_chart.send_event("aoe_burst")
		state_chart.send_event("end_jumping")


#### Ground Pound

func _on_ground_pound_state_entered() -> void:
	debug_state_label.text = "Ground Pound"
	state_chart.send_event("stop_moving")
	debug_trajectory_mesh.mesh.clear_surfaces()
	velocity = Vector3.ZERO
	sprite.texture = slam_sprite
	var wave_callback: Callable = func(): 
		state_chart.send_event("combo_end")
	spawn_center_wave(ground_pound_wave_radius, 0.8, 2.0, false, wave_callback)


# TODO - rework and clean this up for the slam 
func spawn_center_wave(
	max_radius: float, 
	spawned_wave_time: float = 1.0, 
	spawned_wave_height: float = 4.0, 
	_telegraph: bool = false,
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
	area_collider.collision_layer = pow(2, 7)
	area_collider.collision_mask = pow(2, 2-1) + pow(2, 7-1) # Player & Cover
	area_collider.monitoring = true
	
	get_tree().get_root().add_child(area_collider)
	
	area_collider.global_position = area_pos
	area_collider.body_entered.connect(_on_wave_collision)
	#area_collider.body_entered.connect(area_collider.queue_free.unbind(1))
	
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
	#SoundManager.play_sound(TEMP_sfx_area_1)
	var tween = get_tree().create_tween()
	tween.tween_property(mesh, "bottom_radius", max_radius, spawned_wave_time)
	tween.parallel().tween_property(mesh, "top_radius", max_radius, spawned_wave_time)
	tween.parallel().tween_property(area_collider_shape.shape, "radius", max_radius, spawned_wave_time)
	tween.tween_callback(debug_mesh_instance.queue_free)
	tween.tween_callback(area_collider.queue_free)
	tween.tween_callback(callback)


func _on_wave_collision(body: Node3D) -> void:
	if body == target:
		body.health_component.damage(ground_wave_damage)
	elif body is Cover:
		destroy_cover(body)

#### PHASE 3 ==========================

func _on_phase_3_state_entered() -> void:
	current_phase = 3
	phase_debug_label.text = "Phase 3"
	hide_shield()
	phase_stance = Stance.AGGRESSIVE
	air_slam_timer.wait_time *= 0.7
	select_attack()


#### Phase 2-3 | Air Slam Closer
func _on_air_slam_closer_targeting_state_entered() -> void:
	debug_state_label.text = "Air Slam | Targeting"
	#hurtbox.set_deferred("monitoring", true)
	state_chart.send_event("start_targeting")
	
	await get_tree().create_timer(1.0).timeout
	
	state_chart.send_event("start_attack")

func _on_air_slam_closer_recover_state_entered() -> void:
	debug_state_label.text = "Air Slam | Recovery"
	
	state_chart.send_event("stop_moving")
	anim_player.play("RESET")
	await get_tree().create_timer(attack_recovery_time).timeout
	
	# Hammer Ground follow up if the player doesn't escape
	if current_phase > 2:
		var horizontal_distance = Vector2(
			self.global_position.x, 
			self.global_position.z
		).distance_to(Vector2(
			target.global_position.x,
			target.global_position.z
		))
		if horizontal_distance < 16:
			state_chart.send_event("start_hammer_ground_attack")
			return
	
	air_slam_timer.start(air_slam_cooldown)
	select_attack()
	state_chart.send_event("end_recovery")


#### Phase 3 | Hammer Ground
func _on_hammer_ground_targeting_state_entered() -> void:
	debug_state_label.text = "Hammer Ground | Targeting"
	#hurtbox.set_deferred("monitoring", true)
	state_chart.send_event("start_targeting")
	await get_tree().create_timer(0.5).timeout
	state_chart.send_event("start_attack")


func _on_hammer_ground_hammering_state_entered() -> void:
	debug_state_label.text = "Hammer Ground | Hammering"
	anim_player.play("hammer_ground")
	await anim_player.animation_finished
	state_chart.send_event("end_attack")


func _on_hammer_ground_recover_state_entered() -> void:
	debug_state_label.text = "Hammer Ground | Recovery"
	state_chart.send_event("stop_moving")
	await get_tree().create_timer(attack_recovery_time).timeout
	anim_player.play("RESET")
	select_attack()
	state_chart.send_event("end_recovery")


func _on_inactive_state_entered() -> void:
	velocity.x = 0
	velocity.z = 0


func _on_defensive_state_entered() -> void:
	show_shield()


func _on_move_to_center_state_entered() -> void:
	debug_state_label.text = "Move To Center"
	hurtbox.set_deferred("monitoring", false)
	state_chart.send_event("start_jumping")
	
	anim_player.play("air_slam_intro")
	await anim_player.animation_finished
	state_chart.send_event("end_jumping")
	
	hurtbox.body_entered.connect(_air_slam_damage)
	
	await get_tree().create_timer(1.0).timeout
	self.velocity = Vector3.ZERO
	state_chart.send_event("start_shield_slam")


func _on_defensive_state_exited() -> void:
	hide_shield()
