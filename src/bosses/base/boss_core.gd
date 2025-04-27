extends CharacterBody3D
class_name BossCore

## Emit when boss HP drop to 0.
signal died
signal death_anim_finished
## Emit after collected the barrel, 
## or same time as `died` signal if already collected.
signal defeated(boss: BossCore)
#
signal chip_dropped(value: int)

enum BossIdEnum {
	NONE,
	BASE,
	SLOTS,
	ROULETTE,
	BARTENDER,
	PIT
}

@export var boss_id: BossIdEnum
@export var chip_scene: PackedScene
@export var chip_spawn_chance: float = 0.4
@export var chip_spawn_force: float = 700.0
@export var chip_spawn_dps_threshold: float = 25.0
@export var chip_spawn_mult_cap: int = 3
@export_subgroup("DPS Dealt In Last X Seconds")
@export var dps_dealt_window: float = 1.8
@onready var dps_dealt_window_timer: Timer = $DPSWindowTimer
var dps_accumulated_in_window: float = 0.0:
	set(value):
		dps_accumulated_in_window = value
		if dps_dealt_window_timer.is_stopped():
			dps_dealt_window_timer.start(dps_dealt_window)

@export_category("Barrels")
@export var barrel_to_drop: BarrelDataResource
@export var barrel_pickup_scene: PackedScene
var debug_trajectory_mesh: MeshInstance3D


@export_category("SFX")
@export var sfx_players: Array[AudioStreamPlayer3D]
@export var sfx_awaken: AudioStream
@export var sfx_hit: Array[AudioStream]
@export var sfx_death: AudioStream
@export var sfx_telegraph: AudioStream
@export var sfx_slowmo: AudioStream

@export var navigation_component: NavigationComponent
@export var health_component: HealthComponent

@onready var sprite: Sprite3D = $Sprite3D
@onready var debug_mesh: MeshInstance3D = $DebugMesh
@onready var debug_state_label: Label3D = $DebugStateLabel
@onready var debug_dist_label: Label3D = $DebugDistanceLabel
@onready var state_chart: StateChart = $StateChart

@export_group("Sprites")
@export var base_sprite: CompressedTexture2D
@export var hurt_sprite: CompressedTexture2D
@export var death_sprites: Array[CompressedTexture2D]
@export_subgroup("Hurt Frame")
# TODO - make this an actual stagger that delays/interrupts attacks?
@export var hurt_frame_window: float = 0.6
@export var hurt_frame_cooldown: float = 1.5
@onready var hurt_frame_timer: Timer = $HurtFrameTimer
@onready var hurt_frame_cooldown_timer: Timer = $HurtFrameCooldownTimer

@export var current_phase: int = 1

@export var attack_recovery_time: float = 0.5

# Make sure the boss doesn't spam attacks
# TODO - make this more modular
var max_sequential_phases: int = 3
var charge_phase_count: int = 0
var ranged_phase_count: int = 0
var area_phase_count: int = 0

# Charge Attack
@export var telegraph_time: float = 0.25
@export var charge_force: float = 8.0

# Projectile Attack
@export var projectile_scene: PackedScene
@export var projectiles_per_phase: int = 5
@export var delay_per_projectile: float = 0.6
var projectile_round_count: int = 0
@export var max_projectile_rounds: int = 2

var ranged_move_points: Array[Node]
var area_move_points: Array[Node]

# Area Attack
@export var area_damage: float = 25.0
@export var areas_per_phase: int = 6
@export var area_spawn_time: float = 1.5
@export var delay_per_area: float = 0.0
var areas_finished: int = 0:
	set(value):
		areas_finished = value
		if areas_finished == areas_per_phase:
			state_chart.send_event("finish_area_attack")
			areas_finished = 0
var area_round_count: int = 0
@export var max_area_rounds: int = 2
#
@export var area_size: float = 16.0
@export var area_rings: int = 1
# For cleanup on scene change
var spawned_area_objects = []

@onready var collider: CollisionShape3D = $CollisionShape3D
@onready var hurtbox: Area3D = $Hurtbox
@onready var health_ui = $UI/HealthUI/BossHealthContainer
@onready var anim_player: AnimationPlayer = $AnimationPlayer

@export var MAX_SPEED: float = 5.0
@export var FRICTION: float = 1.0
@export var TURN_SPEED_FAST: float = 7.5
@export var TURN_SPEED_SLOW: float = 5.0
const MAX_FALL_SPEED: float = 50.0
const ACCEL_RATE: float = 40.0
const JUMP_FORCE: float = 8
@export var GRAVITY: float = 14

var vel_vertical: float = 0

@export var target: Node3D:
	set(value):
		target = value
		if target:
			if not target.is_node_ready():
				await target.ready
			navigation_component.target = target
var cached_target: Node3D


func _ready() -> void:
	randomize()
	# If the player has beaten all bosses, buff them for the replay value
	if GameManager.all_bosses_defeated:
		health_component.max_health *= 2
		health_component.initialize_health()
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)
	debug_trajectory_mesh = MeshInstance3D.new()
	debug_trajectory_mesh.mesh = ImmediateMesh.new()
	get_tree().get_root().add_child.call_deferred(debug_trajectory_mesh)
	#debug_mesh.visible = false
	await owner.ready


func _physics_process(delta: float) -> void:
	vel_vertical -= GRAVITY * delta
	vel_vertical = clamp(vel_vertical, -MAX_FALL_SPEED, 10000)
	velocity.y = vel_vertical

	move_and_slide()


func jump(multiplier = 1.0) -> void:
	vel_vertical = JUMP_FORCE * multiplier


func show_health() -> void:
	health_ui.show_ui()


func hide_health() -> void:
	health_ui.hide_ui()


func _turn_towards_target(speed: float, delta: float) -> void:
	var direction: Vector3 = self.global_position.direction_to(target.global_position)
	self.rotation.y = lerp_angle(
		self.rotation.y, atan2(
			- direction.x, -direction.z
		),
		delta * speed
	)


func activate() -> void:
	show_health()
	SoundManager.play_sound(sfx_awaken, "SFX")


func draw_debug_sphere(location: Vector3, size: float, color: Color) -> MeshInstance3D:
	# Will usually work, but you might need to adjust this.
	var scene_root = get_tree().root.get_children()[0]
	# Create sphere with low detail of size.
	var sphere = SphereMesh.new()
	sphere.radial_segments = 4
	sphere.rings = 4
	sphere.radius = size
	sphere.height = size * 2
	# Bright red material (unshaded).
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.flags_unshaded = true
	sphere.surface_set_material(0, material)

	# Add to meshinstance in the right place.
	var node = MeshInstance3D.new()
	node.mesh = sphere
	node.global_transform.origin = location
	scene_root.add_child(node)

	return node


func get_available_sfx_player() -> AudioStreamPlayer3D:
	for player: AudioStreamPlayer3D in sfx_players:
		if player.playing:
			continue
		return player

	var players_ending_soon = sfx_players.duplicate()
	players_ending_soon.sort_custom(
		func(a, b):
			var a_time_left: float = a.stream.get_length() - a.get_playback_position()
			var b_time_left: float = b.stream.get_length() - b.get_playback_position()
			if a_time_left < b_time_left:
				return a
			return b
	)
	var fallback_player: AudioStreamPlayer3D = players_ending_soon.front()
	fallback_player.stop()

	return fallback_player


func drop_barrel() -> void:
	# Check if we've already given the player this barrel
	if barrel_to_drop in GameManager.inventory_barrels or barrel_to_drop in GameManager.equipped_barrels:
		push_warning("Barrel [%s] already collected, exiting level." % barrel_to_drop.barrel_name)
		# If we don't have a barrel to spawn, emit the signal to end the level
		defeated.emit(self)
		return

	# Instance a pickup object with the barrel data
	var barrel = barrel_pickup_scene.instantiate()
	barrel.data = barrel_to_drop

	# Calculate a path for the barrel to move
	var collider_height: float
	if collider.shape is SphereShape3D:
		collider_height = collider.shape.radius
	else:
		collider_height = collider.shape.height
	var start_pos: Vector3 = self.global_position + Vector3(0, collider_height / 2, 0)
	var goal_pos: Vector3 = start_pos.lerp(target.global_position, 0.7)

	# Snap to floor
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		goal_pos,
		goal_pos - Vector3(0, 100, 0),
		int(pow(2, 1 - 1) + pow(2, 7 - 1))
	)
	var result = space_state.intersect_ray(query)
	if result:
		goal_pos.y = result.position.y + 1.5

	# Generate path to follow
	var path = Path3D.new()
	var curve = Curve3D.new()
	var mid_point: Vector3 = start_pos.lerp(goal_pos, 0.5) + Vector3(0, 5.0, 0)

	#draw_debug_sphere(start_pos, 0.5, Color.GREEN)
	#draw_debug_sphere(goal_pos, 0.5, Color.YELLOW)
	#draw_debug_sphere(mid_point, 0.5, Color.ORANGE)
	#draw_debug_sphere(target.global_position, 0.5, Color.RED)

	# Calculate bezier control points
	var out_0 = (mid_point - start_pos) * 0.6667
	var in_1 = (mid_point - goal_pos) * 0.6667
	curve.add_point(start_pos, Vector3.ZERO, out_0)
	curve.add_point(goal_pos, in_1, Vector3.ZERO)
	path.curve = curve

	# Add the path to the scene
	var scene_root = get_tree().root.get_children()[7]
	scene_root.add_child(path)
	var path_follow = PathFollow3D.new()
	path.add_child(path_follow)

	# Add the barrel to the path
	path_follow.add_child(barrel)
	barrel.global_position = path_follow.global_position

	# Connect the barrel pickup to the end of the level
	barrel.collected.connect(_on_barrel_collected)

	# Throw the barrel towards the player in an arc using kinematics
	var tween = get_tree().create_tween()
	tween.tween_property(path_follow, "progress_ratio", 1.0, 1.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(
		func():
			path_follow.remove_child(barrel)
			scene_root.add_child(barrel)
			barrel.global_position = goal_pos
			scene_root.remove_child(path)
			path.queue_free()
	)


func _on_barrel_collected(_data: BarrelDataResource) -> void:
	# TODO - show UI with new barrel effects
	#
	# Wait for player to click continue
	#
	defeated.emit(self)


func select_attack() -> void:
	match current_phase:
		1:
			select_attack_phase_1()
		2:
			select_attack_phase_2()
		_:
			push_error("Invalid phase %s" % current_phase)


func select_attack_phase_1() -> void:
	pass


func select_attack_phase_2() -> void:
	pass


func _exit_tree() -> void:
	for object in spawned_area_objects:
		for node in object:
			if is_instance_valid(node):
				node.queue_free()

func boss_death_slow_mo() -> bool:
	SoundManager.play_sound(sfx_slowmo, "SFX")
	var original_time_scale = Engine.time_scale
	Engine.time_scale = 0.1
	await get_tree().create_timer(2 * Engine.time_scale).timeout
	Engine.time_scale = original_time_scale
	SoundManager.stop_sound(sfx_slowmo)
	return true


## ======== State Chart Methods ========

### MOVEMENT --------------------------------
#### IDLE
func _on_movement_idle_state_entered() -> void:
	navigation_component.disable()

func _on_movement_idle_state_physics_processing(delta: float) -> void:
	if velocity.x > 0.0:
		velocity.x = lerp(velocity.x, 0.0, delta * FRICTION)
	if velocity.z > 0.0:
		velocity.z = lerp(velocity.z, 0.0, delta * FRICTION)

#### TARGETING
func _on_movement_targeting_state_entered() -> void:
	navigation_component.disable()

func _on_movement_targeting_state_physics_processing(delta: float) -> void:
	if velocity.x > 0.0:
		velocity.x = lerp(velocity.x, 0.0, delta * FRICTION)
	if velocity.z > 0.0:
		velocity.z = lerp(velocity.z, 0.0, delta * FRICTION)
	if target:
		_turn_towards_target(TURN_SPEED_FAST, delta)

#### WALKING
func _on_movement_walking_state_entered() -> void:
	navigation_component.enable()

func _on_movement_walking_state_physics_processing(delta: float) -> void:
	if target:
		_turn_towards_target(TURN_SPEED_SLOW, delta)

#### CHARGING
func _on_movement_charging_state_entered() -> void:
	navigation_component.disable()
	hurtbox.monitoring = true
	var charge_dir = - self.global_basis.z
	var charge_impulse = self.global_position.distance_to(target.global_position) * charge_force
	velocity += charge_dir * charge_impulse

func _on_movement_charging_state_physics_processing(_delta: float) -> void:
	velocity.x = lerp(velocity.x, 0.0, 0.05)
	velocity.z = lerp(velocity.z, 0.0, 0.05)

	if velocity.x == 0 and velocity.z == 0:
		state_chart.send_event("end_charge")

func _on_movement_charging_state_exited() -> void:
	hurtbox.monitoring = false

#### CHARGING
func _on_movement_jumping_state_entered() -> void:
	pass # Replace with function body.

func _on_movement_jumping_state_physics_processing(_delta: float) -> void:
	pass # Replace with function body.


### HEALTH --------------------------------
#### HIT
func _on_health_hit_state_entered() -> void:
	sprite.modulate = Color.RED
	await get_tree().create_timer(0.05).timeout
	state_chart.send_event("end_damage")

func _on_health_hit_state_exited() -> void:
	sprite.modulate = Color.WHITE

#### DEAD
func _on_health_dead_state_entered() -> void:
	if anim_player.is_playing():
		anim_player.stop()
		anim_player.play("RESET")
	for _sprite in death_sprites:
		sprite.texture = _sprite
		await get_tree().create_timer(1.0).timeout
	sprite.modulate = Color.DARK_SLATE_BLUE
	death_anim_finished.emit()

### ATTACKING --------------------------------
#### TELEGRAPH
func _on_attack_telegraph_state_entered() -> void:
	sprite.modulate = Color.CYAN


func _on_attack_telegraph_state_exited() -> void:
	sprite.modulate = Color.WHITE


## ======== Signal Callback Methods ========

func _on_health_changed(new_health: float, prev_health: float) -> void:
	if new_health < prev_health:
		state_chart.send_event("start_damage")
		SoundManager.play_sound_with_pitch(sfx_hit.pick_random(), randf_range(0.7, 1.2), "SFX")
	if new_health < prev_health:
		dps_accumulated_in_window += abs(prev_health - new_health)
		if dps_accumulated_in_window > chip_spawn_dps_threshold:
			# Play a hurt frame when we do enough DPS
			# TODO - let this interrupt/restart the attack telegraph for some attacks
			if hurt_frame_timer.is_stopped() and hurt_frame_cooldown_timer.is_stopped():
				sprite.texture = hurt_sprite
				hurt_frame_timer.start(hurt_frame_window)
			# Increase chip spawn rate based on DPS
			var chip_mult = snapped(dps_accumulated_in_window / chip_spawn_dps_threshold, 1)
			chip_mult = min(chip_mult, chip_spawn_mult_cap)
			print("DPS dealt: %s | chips spawned: %s" % [dps_accumulated_in_window, chip_mult] )
			for i in chip_mult:
				if randf() < chip_spawn_chance:
					continue
				# TODO - modify spawned chip value chance based on dps
				var chip = chip_scene.instantiate() as RigidBody3D
				GameManager.player.get_parent().add_child(chip)
				chip.global_position = self.global_position
				chip.rotate_y(randf_range(0, 2 * PI))
				chip.apply_central_force(-chip.global_basis.z * chip_spawn_force)
				chip.apply_central_force(Vector3.UP * chip_spawn_force / 10)
				chip_dropped.emit(chip.value)
			# Stop the dps timer and set the accumulated dps to 0
			dps_dealt_window_timer.stop()
			dps_accumulated_in_window = 0.0


func _on_died() -> void:
	died.emit()
	state_chart.send_event("death")
	state_chart.send_event("stop_moving")
	state_chart.send_event("deactivate")
	await death_anim_finished
	drop_barrel()
	await boss_death_slow_mo()
	if not self in GameManager.bosses_defeated:
		GameManager.bosses_defeated.append(boss_id)
		GameManager.all_bosses_defeated = GameManager.bosses_defeated.size() == 4


func _on_hurtbox_body_entered(_body: Node3D) -> void:
	pass


func _on_dps_window_timer_timeout() -> void:
	# TODO - check for chip spawn threshold
	dps_accumulated_in_window = 0.0


func _on_hurt_frame_timer_timeout() -> void:
	sprite.texture = base_sprite
	hurt_frame_cooldown_timer.start(hurt_frame_cooldown)
