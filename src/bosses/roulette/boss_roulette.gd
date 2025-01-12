extends BossCore

@onready var debug_phase_label: Label3D = $DebugPhaseLabel

var wheel_rotation_speed: float = 0.6

@export var barrier_phase_count: int = 3
@export var shields_phase_count: int = 1
@export var ball_phase_count: int = 1
var previous_phase: String

# Barrier
@export var barrier_sweep_speed: float = 1.7

# Shields
@onready var shields_parent: Node3D = $Shields
@export var shield_scene: PackedScene
@export var shields_spawn_cooldown: float = 15.0
@export var shields_max_time: float = 12.0
@onready var shields_spawn_timer: Timer = $ShieldsSpawnTimer
@onready var shields_absorb_timer: Timer = $ShieldsAbsorbTimer
@export var shield_count: int = 5
@export var shield_distance: float = 6.0
@export var shield_height: float = 3.3

# Balls
@export var ball_scene: PackedScene
var ball_spawn_positions: Array
var last_spawn: Node3D
@export var balls_to_spawn: int = 1
@export var max_ball_lifetime: float = 10.0
var active_balls: Array = []

# Pushback Wave
@export var max_wave_radius: float = 32.0
@export var max_center_pushback_radius: float = 8.0
@export var wave_time: float = 0.8
@export var wave_height: float = 1.5
@export var wave_pushback_force: float = 35.0
@export var wave_damage: float = 10.0


func _ready() -> void:
	randomize()
	GRAVITY = 0.0
	hurtbox.visible = false
	shields_parent.position.y -= 30.0
	shields_spawn_timer.wait_time = shields_spawn_cooldown
	shields_absorb_timer.wait_time = shields_max_time
	ball_spawn_positions = get_tree().get_nodes_in_group("boss_ball_marker")
	super()


func activate() -> void:
	super()
	state_chart.send_event("start_phase_1")
	change_phase_1()
	#change_phase()


func change_phase_1() -> void:
	var possible_phases = [
		"start_barrier_attack",
		"start_ball_attack",
		"start_pushback_attack",
	]
	if barrier_phase_count == max_sequential_phases:
		possible_phases.erase("start_barrier_attack")
		barrier_phase_count = 0
	if ball_phase_count == max_sequential_phases:
		possible_phases.erase("start_ball_attack")
		ball_phase_count = 0
	
	# If we've somehow exluded all of the possible phases, 
	# the counters have been reset so just call this method again.
	if possible_phases == []:
		change_phase_1()
		return
	
	for phase in possible_phases.duplicate():
		if phase != previous_phase:
			possible_phases.append(phase)
	
	var new_phase: String = possible_phases[randi_range(0, possible_phases.size() - 1)]
	previous_phase = new_phase
	print(new_phase)
	state_chart.send_event(new_phase)


func spawn_ball() -> RouletteBall:
	var spawn: Node3D
	if last_spawn:
		var last_spawn_idx = ball_spawn_positions.find(last_spawn)
		var new_idx = last_spawn_idx + 2
		if new_idx > ball_spawn_positions.size() - 1:
			new_idx -= ball_spawn_positions.size() - 1
		spawn = ball_spawn_positions[new_idx]
	else:
		var spawns_furthest = ball_spawn_positions.duplicate()
		spawns_furthest.sort_custom(
			func(a, b):
				var a_dist = a.global_position.distance_to(target.global_position)
				var b_dist = b.global_position.distance_to(target.global_position)
				if a_dist > b_dist:
					return true
				return false
		)
		spawn = spawns_furthest.front()
	last_spawn = spawn
	var new_ball: RouletteBall = ball_scene.instantiate()
	
	get_tree().get_root().add_child(new_ball)
	new_ball.global_position = spawn.global_position
	new_ball.target = target
	new_ball.apply_central_force(spawn.global_position.direction_to(Vector3.ZERO) * 500)
	
	active_balls.append(new_ball)
	return new_ball


func _on_hurtbox_body_entered(body: Node3D) -> void:
	SoundManager.play_sound(TEMP_sfx_charge_impact)
	if body == target:
		target.health_component.damage(20)
		hurtbox.set_deferred("monitoring", false)
		await get_tree().create_timer(0.2).timeout
		hurtbox.set_deferred("monitoring", true)


## State behaviour

func _on_movement_targeting_state_physics_processing(delta: float) -> void:
	if target:
		_turn_towards_target(wheel_rotation_speed, delta)


func _on_phase_1_state_entered() -> void:
	debug_phase_label.text = "Phase 1"
	state_chart.send_event("start_shields")


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
	barrier_phase_count += 1
	await get_tree().create_timer(attack_recovery_time).timeout
	change_phase_1()
	state_chart.send_event("restart_targeting")
	# TODO - add fire again option


func _on_shields_targeting_state_entered() -> void:
	state_chart.send_event("start_targeting")
	#await get_tree().create_timer(2.0).timeout
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
	tween.tween_callback(shields_absorb_timer.start)
	
	# TODO - add projectile/wave attack at the same time?

func _check_shields() -> void:
	if shields_parent.get_child_count() == 0:
		state_chart.send_event("shields_destroyed")

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
		health_regained += shield.health_component.current_health
		var tween = get_tree().create_tween()
		tween.tween_property(shield, "position", Vector3(0, shield_height, 0), 0.3).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(shield, "scale", Vector3(0, 0, 0), 0.3).set_trans(Tween.TRANS_SINE)
		tween.tween_callback(shield.queue_free)
		tween.tween_callback(health_component.heal.bind(health_regained))
		await tween.finished
	state_chart.send_event("shields_absorbed")

func _on_shields_recover_state_entered() -> void:
	shields_phase_count += 1
	await get_tree().create_timer(attack_recovery_time).timeout
	shields_spawn_timer.start()
	state_chart.send_event("end_shields")

#
func _on_ball_projectile_targeting_state_entered() -> void:
	debug_state_label.text = "Multiball | Targeting"
	state_chart.send_event("start_targeting")
	#await get_tree().create_timer(1.4).timeout
	state_chart.send_event("launch_balls")

func _on_ball_projectile_launch_balls_state_entered() -> void:
	debug_state_label.text = "Multiball | Launching"
	for i in balls_to_spawn:
		var ball = spawn_ball()
		ball.destroyed.connect(_on_ball_destroyed)
	await get_tree().create_timer(max_ball_lifetime).timeout
	for ball in active_balls:
		ball.destroy()

func _on_ball_destroyed(ball: RouletteBall) -> void:
	active_balls.erase(ball)
	if active_balls.size() == 0:
		state_chart.send_event("balls_destroyed")

func _on_ball_projectile_recover_state_entered() -> void:
	debug_state_label.text = "Multiball | Recovering"
	ball_phase_count += 1
	await get_tree().create_timer(attack_recovery_time).timeout
	change_phase_1()
	state_chart.send_event("end_recovery")


func _on_pushback_wave_spawn_wave_state_entered() -> void:
	debug_state_label.text = "Pushback | Wave"
	
	var wave_attack_callback: Callable = func():
		state_chart.send_event("finish_wave")
	_spawn_center_wave(max_wave_radius, wave_time, wave_height, wave_attack_callback)

func _on_wave_collision(body: Node3D) -> void:
	if body is Player:
		_pushback_effect(body)

func _spawn_center_wave(
	max_radius: float, 
	spawned_wave_time: float = wave_time, 
	spawned_wave_height: float = wave_height, 
	callback: Callable = func(): pass
) -> void:
	SoundManager.play_sound(TEMP_sfx_area_1)
	var area_pos: Vector3 = Vector3.ZERO
	area_pos.y -= wave_height / 2
	
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
	
	var debug_mesh_instance = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	var sphere_mat = ORMMaterial3D.new()
	
	spawned_area_objects.append([area_collider, debug_mesh_instance])
	
	# Generate a visual
	get_tree().get_root().add_child(debug_mesh_instance)
	
	debug_mesh_instance.mesh = mesh
	debug_mesh_instance.cast_shadow = false
	debug_mesh_instance.global_position = area_pos
	
	mesh.bottom_radius = 0.01
	mesh.top_radius = 0.01
	mesh.height = spawned_wave_height
	mesh.material = sphere_mat
	
	sphere_mat.transparency = true
	sphere_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere_mat.cull_mode = 2
	sphere_mat.albedo_color = Color(Color.CYAN, 0.5)
	
	# Animate the visual
	var tween = get_tree().create_tween()
	tween.tween_property(mesh, "bottom_radius", max_radius, spawned_wave_time)
	tween.parallel().tween_property(mesh, "top_radius", max_radius, spawned_wave_time)
	tween.parallel().tween_property(area_collider_shape.shape, "radius", max_radius, spawned_wave_time)
	tween.tween_callback(func():
		debug_mesh_instance.queue_free()
		area_collider.queue_free()
	)
	tween.tween_callback(callback)

func _pushback_effect(body: Node3D) -> void:
	body.health_component.damage(wave_damage)
	var pushback_vector = self.global_position.direction_to(body.global_position)
	
	body.velocity = Vector3.ZERO
	body.vel_horizontal += Vector2(pushback_vector.x, pushback_vector.z) * wave_pushback_force 
	body.vel_vertical += pushback_vector.y * wave_pushback_force 

func _on_pushback_wave_recover_state_entered() -> void:
	debug_state_label.text = "Pushback | Recovering"
	await get_tree().create_timer(attack_recovery_time).timeout
	change_phase_1()
	state_chart.send_event("end_recovery")

func _on_pushback_area_body_entered(body: Node3D) -> void:
	if body is Player:
		wave_damage /= 10.0
		body.dash_disabled = true
		var callback = func(): body.dash_disabled = false
		_spawn_center_wave(max_center_pushback_radius, 0.1, 58, callback)
		wave_damage *= 10.0
