extends BossCore

signal change_wheel_speed(speed: float)

@onready var debug_phase_label: Label3D = $DebugPhaseLabel
@onready var held_ball_marker_pivot: Node3D = $HeldBallPivot
@onready var hurtbox_mesh: MeshInstance3D = hurtbox.get_node("MeshInstance3D")
var wheel_rotation_speed: float = 0.0

@export_category("SFX")

@export_category("Phases")
@export var phase_2_health_percentage_trigger: float = 0.66
@export var phase_3_health_percentage_trigger: float = 0.33
var previous_phase: String

# Shields
@export_group("Shields")
@onready var shields_parent: Node3D = $Shields
@export var shield_scene: PackedScene
@export var shields_spawn_cooldown: float = 15.0
@export var shields_max_time: float = 12.0
@onready var shields_spawn_timer: Timer = $ShieldsSpawnTimer
@onready var shields_absorb_timer: Timer = $ShieldsAbsorbTimer
@export var shield_count: int = 4
@export var shield_distance: float = 6.0
@export var shield_height: float = 3.3
@export_subgroup("SFX")
@export var sfx_shield_amb: Array[AudioStream]
@onready var shield_sfx_player: AudioStreamPlayer3D = $CentralStreamPlayer

# Barrier
@export_group("Barrier Sweep")
@export var barrier_targeting_delay: float = 2.0
@export var barrier_sweep_time: float = 1.7
@onready var barrier_targeting_timer = $BarrierTargetingTimer
@export_subgroup("SFX")
@export var sfx_barrier_sweep: Array[AudioStream]
@onready var barrier_sfx_player: AudioStreamPlayer3D = $Hurtbox/MeshInstance3D/BarrierStreamPlayer
# Multiball
@export_group("Multiball")
@export var ball_scene: PackedScene
@export var balls_to_spawn_phase_1: int = 3
@export var balls_to_spawn_phase_2: int = 6
@export var balls_to_spawn_phase_3: int = 11
@export var balls_to_attack_phase_3: int = 3
@export var ball_attack_delay: float = 1.0
@export var max_ball_lifetime: float = 8.0
@onready var ball_kill_timer: Timer = $BallKillTimer
var active_balls: Array = []
var passive_balls: Array = []
var ball_spawn_positions: Array
var available_spawns: Array
# TODO - add ball spawn SFX
# Shockwave
@export_group("Shockwave")
@export var max_wave_radius: float = 24.0
@export var wave_time: float = 0.7
@export var wave_height: float = 1.0
@export var wave_pushback_force: float = 35.0
@export var wave_damage: float = 10.0
@export var wave_material: ShaderMaterial
@export_subgroup("Center Pushback")
@onready var pushback_area: Area3D = $PushbackArea
@export var max_center_pushback_radius: float = 8.0
@export_subgroup("SFX")
@export var sfx_shockwave_amb: Array[AudioStream]
@onready var shockwave_sfx_player: AudioStreamPlayer3D = $CentralStreamPlayer
# Drop Segments
@export_group("Drop Segments")
@export var drop_delay: float = 0.5
@export var drop_time: float = 1.0
@export var drop_return_delay: float = 3.0
@onready var drop_floor_tween: Tween
var floor_segments: Array
var dropped_segments: Array
@export_subgroup("SFX")
@export var sfx_drop_amb: Array[AudioStream]
@onready var drop_sfx_player: AudioStreamPlayer3D = $SegmentStreamPlayer


func _ready() -> void:
	super()
	GRAVITY = 0.0
	hurtbox.visible = false
	
	shields_parent.position.y -= 30.0
	shields_spawn_timer.wait_time = shields_spawn_cooldown
	shields_absorb_timer.wait_time = shields_max_time
	
	ball_spawn_positions = get_tree().get_nodes_in_group("boss_ball_marker")
	available_spawns = ball_spawn_positions.duplicate()
	ball_kill_timer.wait_time = max_ball_lifetime


func _physics_process(delta: float) -> void:
	super(delta)
	held_ball_marker_pivot.look_at(target.global_position)


func activate() -> void:
	super()
	change_phase(current_phase)


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


# TODO - condense this logic to be quicker and easier to configure attack chances
func select_attack_phase_1() -> void:
	var _dist_to_target = self.global_position.distance_to(target.global_position)
	var possible_phases = [
		"start_barrier_attack",
		"start_ball_attack",
	]
	#if barrier_phase_count == max_barrier_phase_count:
		#possible_phases.erase("start_barrier_attack")
		#barrier_phase_count = 0
	#if ball_phase_count == max_ball_phase_count:
		#possible_phases.erase("start_ball_attack")
		#ball_phase_count = 0
	
	# If we've somehow exluded all of the possible phases, 
	# the counters have been reset so just call this method again.
	#if possible_phases == []:
		#select_attack()
		#return
	
	if previous_phase:
		possible_phases.erase(previous_phase)
	
	var new_phase: String = possible_phases[randi_range(0, possible_phases.size() - 1)]
	previous_phase = new_phase
	state_chart.send_event(new_phase)


func select_attack_phase_2() -> void:
	var _dist_to_target = self.global_position.distance_to(target.global_position)
	var possible_phases = [
		"start_pushback_attack",
		"start_barrier_attack",
	]
	
	#if barrier_phase_count == max_barrier_phase_count:
		#possible_phases.erase("start_barrier_attack")
		#barrier_phase_count = 0
	#if shockwave_phase_count == max_shockwave_phase_count:
		#possible_phases.erase("start_pushback_attack")
		#shockwave_phase_count = 0
		
	if previous_phase:
		possible_phases.erase(previous_phase)
	
	var new_phase: String = possible_phases[randi_range(0, possible_phases.size() - 1)]
	previous_phase = new_phase
	state_chart.send_event(new_phase)


func select_attack_phase_3() -> void:
	var _dist_to_target = self.global_position.distance_to(target.global_position)
	var possible_phases = [
		"start_drop_attack",
		"start_ball_attack",
	]
	
	if randf() < 0.25:
		possible_phases.append("start_pushback_attack")
	
	if previous_phase and possible_phases.size() > 1:
		possible_phases.erase(previous_phase)
	
	#if drop_phase_count == max_drop_phase_count:
		#possible_phases.erase("start_drop_attack")
		#drop_phase_count = 0
	#if ball_phase_count == max_ball_phase_count:
		#possible_phases.erase("start_ball_attack")
		#ball_phase_count = 0
	#
	#for phase in possible_phases.duplicate():
		#if phase != previous_phase:
			#possible_phases.append(phase)
	#
	
	var new_phase: String = possible_phases[randi_range(0, possible_phases.size() - 1)]
	previous_phase = new_phase
	print(new_phase)
	state_chart.send_event(new_phase)


func _check_shields() -> void:
	if shields_parent.get_child_count() == 0:
		state_chart.send_event("shields_destroyed")


func material_glow(value: float, material: Material, target_color: Color):
	var current_color: Color = material.get("shader_parameter/color")
	var lerp_color := target_color.lerp(current_color, value)
	material.set("shader_parameter/color", lerp_color)
	if material.next_pass:
		material.next_pass.emission = lerp_color


func sweep_barrier(
	sweeps: int = 1,
	sweep_rotation: float = TAU, 
	speed_multiplier: float = 1.0,
	telegraph_delay: float = telegraph_time,
	time_between_sweeps: float = 1.0,
) -> bool:
	for i in sweeps:
		state_chart.send_event("attack_telegraph")
		var telegraph_tween = get_tree().create_tween()
		var barrier_color = hurtbox_mesh.mesh.material.get("shader_parameter/color")
		telegraph_tween.tween_method(material_glow.bind(hurtbox_mesh.mesh.material, Color.RED), 0, 1, telegraph_delay/2)
		telegraph_tween.chain().tween_method(material_glow.bind(hurtbox_mesh.mesh.material, barrier_color), 0, 1, telegraph_delay/2)
		await telegraph_tween.finished
		state_chart.send_event("attack_start")
		
		hurtbox.monitoring = true
		var tween = get_tree().create_tween()
		tween.tween_property(
			self, 
			"rotation:y", 
			self.rotation.y + sweep_rotation, 
			barrier_sweep_time * (sweep_rotation / TAU) / speed_multiplier
		).set_ease(Tween.EASE_IN)
		
		await tween.finished
		hurtbox.monitoring = false
		state_chart.send_event("attack_end")
	await get_tree().create_timer(time_between_sweeps).timeout
	
	return true


func spawn_ball(
	_target: Node3D = target, 
	spawn_force: float = 500, 
	ball_arr: Array = active_balls,
	ball_prop_func: Callable = _set_ball_active_params
) -> RouletteBall:
	var spawn: Node3D
	if available_spawns.size() == 0:
		available_spawns = ball_spawn_positions.duplicate()
	available_spawns.sort_custom(
		func(a, b):
			var a_dist = a.global_position.distance_to(target.global_position)
			var b_dist = b.global_position.distance_to(target.global_position)
			if a_dist > b_dist:
				return true
			return false
	)
	spawn = available_spawns.pop_front()
	
	var new_ball: RouletteBall = ball_scene.instantiate()
	get_tree().get_root().add_child(new_ball)
	new_ball = ball_prop_func.call(new_ball, _target)
	new_ball.global_position = spawn.global_position
	new_ball.look_at(Vector3.ZERO)
	new_ball.destroyed.connect(_on_ball_destroyed)
	
	var spawn_force_vector: Vector3 = spawn.global_position.direction_to(Vector3.ZERO)
	spawn_force_vector.y = 0
	new_ball.apply_central_force(spawn_force_vector * spawn_force)
	
	ball_arr.append(new_ball)
	return new_ball

func _set_ball_active_params(ball: RouletteBall, _target: Node3D = target) -> RouletteBall:
	ball.target = _target
	ball.health_component.is_invincible = false
	ball.max_collisions = 30
	ball.radial_force_magnitude = 2500.0
	ball.central_force_magnitude = 10000.0
	ball.homing_force_magnitude = 6500.0
	ball.mute_sfx = false
	return ball

func _set_ball_passive_params(ball: RouletteBall, _target: Node3D) -> RouletteBall:
	ball.target = null
	ball.health_component.is_invincible = true
	ball.max_collisions = -1
	ball.radial_force_magnitude = 3500.0
	ball.central_force_magnitude = 500.0
	ball.homing_force_magnitude = 0.0
	ball.mute_sfx = true
	#ball.radial_force_magnitude = 3500.0
	
	return ball


func destroy_balls(ball_arr: Array) -> void:
	for ball in ball_arr:
		if is_instance_valid(ball):
			ball.destroy()
	ball_arr = []


func spawn_center_wave(
	max_radius: float, 
	spawned_wave_time: float = wave_time, 
	spawned_wave_height: float = wave_height, 
	telegraph: bool = false,
	callback: Callable = func(): pass
) -> void:
	var area_pos: Vector3 = Vector3.ZERO
	area_pos.y -= wave_height
	
	# Generate a collider
	var area_collider := Area3D.new()
	var area_collider_shape := CollisionShape3D.new()
	var collider_shape := CylinderShape3D.new()
	collider_shape.radius = 0.01
	collider_shape.height = spawned_wave_height
	area_collider_shape.shape = collider_shape
	area_collider.add_child(area_collider_shape)
	area_collider.collision_layer = 0
	area_collider.collision_mask = 2  # Player
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
	
	if telegraph:
		var telegraph_tween = get_tree().create_tween()
		var mesh_color: Color = debug_mesh_instance.mesh.material.get("shader_parameter/color")
		
		telegraph_tween.tween_property(debug_mesh_instance, "mesh:bottom_radius", 6.0, telegraph_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CIRC)
		telegraph_tween.parallel().tween_property(debug_mesh_instance, "mesh:top_radius", 6.0, telegraph_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CIRC)
		telegraph_tween.parallel().tween_method(material_glow.bind(debug_mesh_instance.mesh.material, Color.RED), 0, 1, telegraph_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CIRC)
		telegraph_tween.parallel().tween_callback(func(): state_chart.send_event("attack_telegraph")).set_delay(0)
		telegraph_tween.chain().tween_property(debug_mesh_instance, "mesh:bottom_radius", 1.0, telegraph_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		telegraph_tween.parallel().tween_property(debug_mesh_instance, "mesh:top_radius", 1.0, telegraph_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		telegraph_tween.parallel().tween_method(material_glow.bind(debug_mesh_instance.mesh.material, mesh_color), 0, 1, telegraph_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		
		await telegraph_tween.finished
	
	state_chart.send_event("attack_start")
	
	# Animate the visual
	#SoundManager.play_sound(TEMP_sfx_area_1)
	shockwave_sfx_player.play()
	var tween = get_tree().create_tween()
	tween.tween_property(mesh, "bottom_radius", max_radius, spawned_wave_time)
	tween.parallel().tween_property(mesh, "top_radius", max_radius, spawned_wave_time)
	tween.parallel().tween_property(area_collider_shape.shape, "radius", max_radius, spawned_wave_time)
	#tween.parallel().tween_property(shockwave_sfx_player, "volume_db", linear_to_db(1.0), spawned_wave_time)
	tween.tween_callback(debug_mesh_instance.queue_free)
	tween.tween_callback(area_collider.queue_free)
	tween.tween_callback(shockwave_sfx_player.stop)
	tween.tween_callback(callback)


func _pushback_effect(body: Node3D) -> void:
	body.health_component.damage(wave_damage)
	var pushback_vector = self.global_position.direction_to(body.global_position)
	
	body.velocity = Vector3.ZERO
	body.vel_horizontal += Vector2(pushback_vector.x, pushback_vector.z) * wave_pushback_force 
	body.vel_vertical += pushback_vector.y * wave_pushback_force 


func drop_floor_segment(segment_arr: Array) -> void:
	var mesh: MeshInstance3D = segment_arr[0]
	var collider: CollisionShape3D = segment_arr[1]
	collider.disabled = true
	
	drop_floor_tween = get_tree().create_tween()
	drop_floor_tween.tween_property(mesh, "position:y", mesh.position.y - 20.0, drop_time)
	drop_floor_tween.parallel().tween_property(mesh, "scale", Vector3.ZERO, drop_time)
	drop_floor_tween.parallel().tween_property(collider, "position:y", collider.position.y - 20.0, drop_time)
	drop_floor_tween.tween_callback(barrier_sfx_player.stop)
	dropped_segments.append(segment_arr)


func return_floor_segment(segment_arr: Array, time: float = drop_time) -> void:
	var mesh: MeshInstance3D = segment_arr[0]
	var collider: CollisionShape3D = segment_arr[1]
	mesh.visible = true
	var tween = get_tree().create_tween()
	tween.tween_property(mesh, "position:y", mesh.position.y + 20.0, time)
	tween.parallel().tween_property(mesh, "scale", Vector3(1, 1, 1), time)
	tween.parallel().tween_property(collider, "position:y", collider.position.y + 20.0, time)
	await tween.finished
	collider.disabled = false


func shake_segment(segment: MeshInstance3D, shake_count: int = 30, shake_amount: float = 0.3) -> bool:
	var cached_mesh_pos = segment.position
	drop_floor_tween = get_tree().create_tween()
	for j in shake_count:
		drop_floor_tween.tween_property(
			segment, 
			"position",
			Vector3(0, randf_range(-shake_amount, shake_amount), 0), 
			0.05
		).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_ELASTIC)
	await drop_floor_tween.finished
	segment.position = cached_mesh_pos
	return true


## ======== Signal Callback Methods ========

func _on_hurtbox_body_entered(body: Node3D) -> void:
	#SoundManager.play_sound(TEMP_sfx_charge_impact)
	if body == target:
		target.health_component.damage(20)
		hurtbox.set_deferred("monitoring", false)
		await get_tree().create_timer(0.2).timeout
		hurtbox.set_deferred("monitoring", true)
	elif body is RouletteBall:
		var impulse = Vector3.UP
		body.apply_central_force(impulse * 3000)


func _on_ball_kill_timer_timeout() -> void:
	destroy_balls(active_balls)


func _on_health_changed(new_health: float, prev_health: float) -> void:
	super(new_health, prev_health)
	
	if new_health < health_component.max_health * phase_3_health_percentage_trigger and current_phase == 2:
		change_phase(3)
	elif new_health < health_component.max_health * phase_2_health_percentage_trigger and current_phase == 1:
		change_phase(2)


func change_phase(new_phase: int) -> void:
	# Check if an attack is in progress
	if not $StateChart/Root/Attacking/Idle.active:
		await $StateChart/Root/Attacking/Idle.state_entered
	# TODO - anims/effects/sound for phase change
	#
	# Change phase
	var phase_event: String
	match new_phase:
		1:
			phase_event = "start_phase_1"
		2:
			phase_event = "start_phase_2"
		3:
			phase_event = "start_phase_3"
	
	state_chart.send_event(phase_event)


func _on_died() -> void:
	super()
	destroy_balls(active_balls)
	destroy_balls(passive_balls)
	pushback_area.set_deferred("monitoring", false)
	change_wheel_speed.emit(0.0)
	wheel_rotation_speed = 0.0
	
	if drop_floor_tween:
		await drop_floor_tween.step_finished
		drop_floor_tween.kill()

	for segment in floor_segments:
		if segment in dropped_segments:
			return_floor_segment(segment, 0.1)
		else:
			segment[0].global_position.y = segment[2]
	dropped_segments = []


func _on_pushback_area_body_entered(body: Node3D) -> void:
	if body is Player:
		wave_damage /= 10.0
		body.dash_disabled = true
		spawn_center_wave(max_center_pushback_radius, 0.1, 58)
		wave_damage *= 10.0
		await get_tree().create_timer(0.8).timeout
		body.dash_disabled = false


## ======== State Chart Methods ========

func _on_movement_targeting_state_physics_processing(delta: float) -> void:
	if target:
		_turn_towards_target(wheel_rotation_speed, delta)


func _on_wave_collision(body: Node3D) -> void:
	if body is Player:
		_pushback_effect(body)


func _on_attack_telegraph_state_entered() -> void:
	shockwave_sfx_player.stream = sfx_telegraph
	shockwave_sfx_player.play()


func _on_attack_telegraph_state_exited() -> void:
	shockwave_sfx_player.stop()


### ATTACK PHASES --------------------------------

#### Any Phase | Shields
func _on_shields_targeting_state_entered() -> void:
	state_chart.send_event("spawn_shields")

func _on_shields_spawn_shields_state_entered() -> void:
	var rotation_increment: float = 2 * PI / shield_count
	
	shield_sfx_player.stream = sfx_shield_amb.pick_random()
	shield_sfx_player.volume_db = linear_to_db(0.1)
	shield_sfx_player.play()
	
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
	tween.parallel().tween_property(shield_sfx_player, "volume_db", linear_to_db(1.0), 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(shields_absorb_timer.start)

func _on_shields_spawn_shields_state_physics_processing(delta: float) -> void:
	shields_parent.rotation.y += delta * wheel_rotation_speed * 4

func _on_shields_spawn_timer_timeout() -> void:
	if health_component.current_health < health_component.max_health:
		state_chart.send_event("start_shields")

func _on_shields_absorb_timer_timeout() -> void:
	state_chart.send_event("shields_timeout")

func _on_shields_absorb_state_entered() -> void:
	var health_regained: float = 0.0
	for shield in shields_parent.get_children():
		if not is_instance_valid(shield):
			continue
		health_regained += shield.health_component.current_health
		var tween = get_tree().create_tween()
		tween.tween_property(shield, "position", Vector3(0, shield_height, 0), 0.3).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(shield, "scale", Vector3(0, 0, 0), 0.3).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(shield_sfx_player, "volume_db", linear_to_db(0.1), 0.8).set_trans(Tween.TRANS_SINE)
		tween.tween_callback(shield.queue_free)
		tween.tween_callback(shield_sfx_player.stop)
		tween.tween_callback(health_component.heal.bind(health_regained))
		await tween.finished
	state_chart.send_event("shields_absorbed")

func _on_shields_recover_state_entered() -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(shield_sfx_player, "volume_db", linear_to_db(0.1), 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(shield_sfx_player.stop)
	
	await get_tree().create_timer(attack_recovery_time).timeout
	shields_spawn_timer.start()
	state_chart.send_event("end_shields")


#### PHASE 1 ==========================
# Sweep
# Multiball

func _on_phase_1_state_entered() -> void:
	debug_phase_label.text = "Phase 1"
	change_wheel_speed.emit(0.6)
	wheel_rotation_speed = 0.6
	current_phase = 1
	state_chart.send_event("start_ball_attack")

#### Phase 1 | Barrier Sweep
func _on_damage_barrier_targeting_state_entered() -> void:
	debug_state_label.text = "Damage Barrier | Targeting"
	
	state_chart.send_event("attack_buildup")
	# Rotate so that the barrier always starts in the same position relative to the player
	look_at(target.global_position)
	self.rotation.x = 0
	
	barrier_sfx_player.stream = sfx_barrier_sweep.pick_random()
	barrier_sfx_player.volume_db = linear_to_db(0.1)
	barrier_sfx_player.play()
	
	var tween = get_tree().create_tween()
	hurtbox_mesh.position.x = 0
	hurtbox_mesh.mesh.size.x = 0
	hurtbox.visible = true
	tween.tween_property(hurtbox_mesh, "position:x", 17, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
	tween.parallel().tween_property(hurtbox_mesh, "mesh:size:x", 35, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
	tween.parallel().tween_property(barrier_sfx_player, "volume_db", linear_to_db(1.0), 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
	await tween.finished
	
	barrier_targeting_timer.start(barrier_targeting_delay)

func _on_barrier_targeting_timer_timeout() -> void:
	state_chart.send_event("barrier_attack_start")

func _on_phase_1_damage_barrier_spawn_barrier_state_entered() -> void:
	debug_state_label.text = "Damage Barrier | Sweep"
	
	var sweep_count: int = 2 if randf() < 0.5 else 1
	await sweep_barrier(sweep_count)
	
	state_chart.send_event("barrier_attack_end")

func _on_damage_barrier_spawn_barrier_state_exited() -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(hurtbox_mesh, "position:x", 0, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CIRC)
	tween.parallel().tween_property(hurtbox_mesh, "mesh:size:x", 0, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUINT)
	await tween.finished
	hurtbox.visible = false

func _on_damage_barrier_recover_state_entered() -> void:
	debug_state_label.text = "Damage Barrier | Recover"
	
	if hurtbox.visible:
		var tween = get_tree().create_tween()
		tween.tween_property(hurtbox_mesh, "position:x", 0, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUINT)
		tween.parallel().tween_property(hurtbox_mesh, "mesh:size:x", 0, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUINT)
		tween.parallel().tween_property(barrier_sfx_player, "volume_db", linear_to_db(0.1), 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUINT)
		await tween.finished
		hurtbox.visible = false
	
	await get_tree().create_timer(attack_recovery_time * 2).timeout
	state_chart.send_event("cooldown_end")
	state_chart.send_event("end_recovery")
	select_attack()

func _on_damage_barrier_state_exited() -> void:
	barrier_targeting_timer.stop()
	state_chart.send_event("attack_end_now")
	if hurtbox.visible:
		var tween = get_tree().create_tween()
		tween.tween_property(hurtbox_mesh, "position:x", 0, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CIRC)
		tween.parallel().tween_property(hurtbox_mesh, "mesh:size:x", 0, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUINT)
		tween.parallel().tween_property(barrier_sfx_player, "volume_db", linear_to_db(0.1), 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUINT)
		await tween.finished
		hurtbox.visible = false
		barrier_sfx_player.stop()
		


#### Phase 1 | Multiball
func _on_ball_projectile_targeting_state_entered() -> void:
	debug_state_label.text = "Multiball | Targeting"
	state_chart.send_event("attack_buildup")
	await get_tree().create_timer(ball_attack_delay).timeout
	state_chart.send_event("launch_balls")

func _on_ball_projectile_launch_balls_state_entered() -> void:
	debug_state_label.text = "Multiball | Launching"
	state_chart.send_event("attack_start")
	for i in balls_to_spawn_phase_1:
		var ball = spawn_ball()
	ball_kill_timer.start(max_ball_lifetime)

func _on_ball_destroyed(ball: RouletteBall) -> void:
	active_balls.erase(ball)
	if active_balls.size() == 0:
		state_chart.send_event("balls_destroyed")
	state_chart.send_event("attack_end")

func _on_ball_projectile_recover_state_entered() -> void:
	debug_state_label.text = "Multiball | Recovering"
	await get_tree().create_timer(attack_recovery_time).timeout
	state_chart.send_event("cooldown_end")
	select_attack()
	state_chart.send_event("end_recovery")


#### PHASE 2 ==========================
# Shields 
# Shockwave
# Sweep

func _on_phase_2_state_entered() -> void:
	destroy_balls(active_balls)
	ball_kill_timer.stop()
	
	debug_phase_label.text = "Phase 2"
	change_wheel_speed.emit(0.7)
	wheel_rotation_speed = 0.7
	
	state_chart.send_event("start_shields")
	
	# Mostly for decorative effect, roulette balls that circle the walls of the arena
	for i in balls_to_spawn_phase_2:
		var ball = spawn_ball(null, 500.0, passive_balls, _set_ball_passive_params)
		var tween = get_tree().create_tween()
		tween.tween_property(ball, "central_force_magnitude", -200, 2.0)
	
	current_phase = 2
	state_chart.send_event("start_pushback_attack")


#### Phase 2 | Shockwave
func _on_phase_2_pushback_wave_targeting_state_entered() -> void:
	debug_state_label.text = "Shockwave | Targeting"
	state_chart.send_event("attack_buildup")
	await get_tree().create_timer(1.2).timeout
	state_chart.send_event("start_wave")

func _on_phase_2_pushback_wave_spawn_wave_state_entered() -> void:
	debug_state_label.text = "Shockwave | Burst"
	
	shockwave_sfx_player.stream = sfx_shockwave_amb.pick_random()
	#shockwave_sfx_player.volume_db = linear_to_db(0.1)
	
	var wave_attack_callback: Callable = func():
		state_chart.send_event("finish_wave")
	spawn_center_wave(max_wave_radius, wave_time, wave_height, true, wave_attack_callback)

func _on_phase_2_pushback_wave_recover_state_entered() -> void:
	debug_state_label.text = "Shockwave | Recovering"
	state_chart.send_event("attack_end")
	await get_tree().create_timer(attack_recovery_time).timeout
	state_chart.send_event("cooldown_end")
	select_attack()
	state_chart.send_event("end_recovery")


### Phase 2 | Barrier Sweep
# Uses the same methods as the first phase, except for the spawn_barrier
# enter state where we can tweak the actual sweep behaviours
func _on_phase_2_damage_barrier_spawn_barrier_state_entered() -> void:
	# 75% chance of 4 slow double sweeps around the wheel
	# 25% chance of 3 rapid single sweeps
	var sweep_count: int = 1
	var sweep_rotation: float = TAU * 2
	var speed_multiplier: float = 0.5
	var label_suffix: String = " (Slow)"
	
	var chance: float = randf()
	if chance < 0.4:
		sweep_count = 3
		sweep_rotation = TAU
		speed_multiplier = 1.1
		label_suffix = " (Fast)"
	
	debug_state_label.text = "Barrier | Sweep" + label_suffix
	await sweep_barrier(sweep_count, sweep_rotation, speed_multiplier)
	
	state_chart.send_event("barrier_attack_end")


#### PHASE 3 ==========================
# Shields 
# Sweep
# Multiball
# Segment Drop

func _on_phase_3_state_entered() -> void:	
	debug_phase_label.text = "Phase 3"
	
	change_wheel_speed.emit(0.8)
	wheel_rotation_speed = 0.8
	current_phase = 3
	
	# Mostly for decorative effect, roulette balls that circle the walls of the arena
	for i in balls_to_spawn_phase_3 - active_balls.size():
		spawn_ball(null, 500.0, passive_balls, _set_ball_passive_params)
	
	state_chart.send_event("start_drop_attack")


### Phase 3 | Segment Drop
func _on_phase_3_dropping_segments_targeting_state_entered() -> void:
	debug_state_label.text = "Segment Drop | Targeting"
	state_chart.send_event("attack_buildup")
	await get_tree().create_timer(1.5).timeout
	state_chart.send_event("start_drop")

func _on_phase_3_dropping_segments_dropping_state_entered() -> void:
	debug_state_label.text = "Segment Drop | Dropping"
	state_chart.send_event("attack_start")
	var drop_count: int = 4
	var segments_to_drop = floor_segments.duplicate()
	# TODO - move this logic into discrete methods for different drop behaviour
	# Get random segment
	# Pattern 1 - alternating segments
	#var chance: float = randf()
	#for i in range(segments_to_drop.size() - 1):
		#if chance < 0.5:
			#if i == 0 or i % 2 == 0:
				#continue
		#else:
			#if i % 2 != 0:
				#continue 
		#var tween = get_tree().create_tween()
		#var segment_mesh = segments_to_drop[i][0]
		#var cached_mesh_pos = segment_mesh.position
		#for j in shake_count:
			#tween.tween_property(
				#segment_mesh, 
				#"position",
				#Vector3(0, randf_range(-shake, shake), 0), 
				#0.05
			#)
		#await tween.finished
		#segment_mesh.position = cached_mesh_pos
		#drop_floor_segment(segments_to_drop[i])
		#await get_tree().create_timer(0.5).timeout
	# Pattern 2 - targeting the player
	for i in drop_count:
		if $StateChart/Root/Health/Dead.active:
			state_chart.send_event("attack_end")
			state_chart.send_event("deactivate")
			return
		
		segments_to_drop.sort_custom(
			# TODO - make this a function for sort closest/furthest to target
			func(a, b):
					var a_dist = a[0].global_position.distance_to(target.global_position)
					var b_dist = b[0].global_position.distance_to(target.global_position)
					if a_dist < b_dist:
						return true
					return false
		)
		var segment_mesh = segments_to_drop.front()[0]
		
		drop_sfx_player.global_position = segment_mesh.global_position
		drop_sfx_player.stream = sfx_drop_amb.pick_random()
		drop_sfx_player.play()
		var tween = get_tree().create_tween()
		tween.tween_property(barrier_sfx_player, "volume_db", linear_to_db(1.0), 0.1).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
		
		await shake_segment(segment_mesh)
		drop_floor_segment(segments_to_drop.pop_front())
		await get_tree().create_timer(drop_delay).timeout
		
	await get_tree().create_timer(drop_return_delay).timeout
	state_chart.send_event("stop_drop")
	state_chart.send_event("attack_end")

func _on_phase_3_dropping_segments_recover_state_entered() -> void:
	debug_state_label.text = "Segment Drop | Recover"
	
	for i in range(dropped_segments.size()):
		return_floor_segment(dropped_segments.pop_front())

	await get_tree().create_timer(attack_recovery_time).timeout
	state_chart.send_event("cooldown_end")
	select_attack()
	state_chart.send_event("end_recovery")


### Phase 3 | Multiball
func _on_phase_3_ball_projectile_targeting_state_entered() -> void:
	debug_state_label.text = "Multiball | Targeting"
	state_chart.send_event("attack_buildup")
	await get_tree().create_timer(ball_attack_delay).timeout
	state_chart.send_event("launch_balls")

func _on_phase_3_ball_projectile_launch_balls_state_entered() -> void:
	debug_state_label.text = "Multiball | Launching"
	state_chart.send_event("attack_start")
	
	# Get the balls furthest from the player so they can see them when they shift
	passive_balls.sort_custom(
		func(a, b):
			var a_dist: float = a.global_position.distance_to(target.global_position)
			var b_dist: float = b.global_position.distance_to(target.global_position)
			if a_dist > b_dist:
				return true
			return false
	)
	for i in range(balls_to_attack_phase_3 - active_balls.size()): 
		var ball = spawn_ball()
		ball.is_flaming = true
		ball = _set_ball_active_params(ball)
		ball.central_force_magnitude = 9000.0
		ball.homing_force_magnitude = 6500.0
		active_balls.push_back(ball)
		ball.apply_central_force(ball.global_position.direction_to(target.global_position) * 2500)
		await get_tree().create_timer(0.5).timeout
	
	state_chart.send_event("end_balls_launch")

func _on_phase_3_ball_projectile_launch_balls_state_exited() -> void:
	await get_tree().create_timer(8.0).timeout
	destroy_balls(active_balls)

func _on_phase_3_projectile_balls_recover_state_entered() -> void:
	debug_state_label.text = "Multiball | Recovering"
	state_chart.send_event("attack_end")
	
	await get_tree().create_timer(attack_recovery_time).timeout
	state_chart.send_event("cooldown_end")
	select_attack()
	state_chart.send_event("end_recovery")
