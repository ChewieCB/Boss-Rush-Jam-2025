extends CharacterBody3D
class_name BossCore

## Emit when boss HP drop to 0.
signal died
signal death_anim_finished
## Emit after collected the barrel,
## Emit after collected the barrel,
## or same time as `died` signal if already collected.
signal defeated(boss: BossCore)
#
signal chip_dropped(value: int)

enum BossIdEnum {
	BASE,
	SLOTS,
	ROULETTE,
	BARTENDER,
	PIT,
	CHIPS,
	ELEVATOR,
	BLACKJACK
}

enum BossStatusEffect {
	NONE,
	BURNING, # High DoT over short time
	POISONED, # DoT over long time
	FROZEN, # Slow movement
	SHOCKED, # Take increased damage
	BLEEDING # Take damage based on their movement
}

@export var target: Node3D:
	set(value):
		target = value
		if target:
			if not target.is_node_ready():
				await target.ready
			navigation_component.target = target
var cached_target: Node3D

@export var boss_id: BossIdEnum
@export var chip_scene: PackedScene
@export var chip_spawn_chance: float = 0.4
@export var chip_spawn_force: float = 700.0
@export var chip_spawn_dps_threshold: float = 25.0
@export var chip_spawn_mult_cap: int = 3

@export_subgroup("Resistance")
@onready var burning_timer: Timer = $StateChart/Root/Status/Burning/BurningTimer
@onready var poisoned_timer: Timer = $StateChart/Root/Status/Poisoned/PoisonedTimer
## 1 = BURN, 2 = POISON
@export var status_resist: Dictionary = {
	BossStatusEffect.BURNING: 1000,
	BossStatusEffect.POISONED: 1000,
	BossStatusEffect.FROZEN: 1000,
	BossStatusEffect.SHOCKED: 1000,
	BossStatusEffect.BLEEDING: 1000,
}
@export var status_duration: Dictionary = {
	BossStatusEffect.BURNING: 10,
	BossStatusEffect.POISONED: 10,
	BossStatusEffect.FROZEN: 10,
	BossStatusEffect.SHOCKED: 10,
	BossStatusEffect.BLEEDING: 1,
}
## Status resist increased by this amount after each status application
@export var increased_status_tolerance: Dictionary = {
	BossStatusEffect.BURNING: 500,
	BossStatusEffect.POISONED: 500,
	BossStatusEffect.FROZEN: 500,
	BossStatusEffect.SHOCKED: 500,
	BossStatusEffect.BLEEDING: 1000,
}
var current_status_buildup: Dictionary = {
	BossStatusEffect.BURNING: 0,
	BossStatusEffect.POISONED: 0,
	BossStatusEffect.FROZEN: 0,
	BossStatusEffect.SHOCKED: 0,
	BossStatusEffect.BLEEDING: 0,
}
@export var elemental_emitting_vfx: Array[Node3D] = [null, null, null, null, null] # VFX that emit as long as bullet/ray persist
const SHOCKED_DMG_MULTIPLIER = 0.25

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
@onready var hurt_sfx_player: AudioStreamPlayer3D = $HurtSFXPlayer
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
@onready var debug_status_label_parent: Node3D = $StatusLabelParent
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

@export_group("Phase")
@export var current_phase: int = 1

# Make sure the boss doesn't spam attacks
# TODO - make this more modular
var max_sequential_phases: int = 3
var charge_phase_count: int = 0
var ranged_phase_count: int = 0
var area_phase_count: int = 0

@export_group("Attacks")
@export var attack_targeting_time: float = 0.5
@export var attack_recovery_time: float = 0.5
@export_subgroup("Charge")
# Charge Attack
@export var telegraph_time: float = 0.25
@export var charge_force: float = 8.0
@export_subgroup("Projectile")
# Projectile Attack
@export var projectile_scene: PackedScene
@export var projectiles_per_phase: int = 5
@export var delay_per_projectile: float = 0.6
var projectile_round_count: int = 0
@export var max_projectile_rounds: int = 2

var ranged_move_points: Array[Node]
var area_move_points: Array[Node]

# Area Attack
@export_subgroup("AoE")
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
@onready var health_ui: BossHealthBar = $UI/HealthUI/BossHealthContainer
@onready var anim_player: AnimationPlayer = $AnimationPlayer

@export_group("Movement")
@export var MAX_SPEED: float = 5.0
@export var FRICTION: float = 1.0
@export var TURN_SPEED_FAST: float = 7.5
@export var TURN_SPEED_SLOW: float = 5.0
const MAX_FALL_SPEED: float = 50.0
const ACCEL_RATE: float = 40.0
const JUMP_FORCE: float = 8
@export var GRAVITY: float = 14
@export_subgroup("Orbiting")
@export var DESIRED_DISTANCE: float = 10.0
@export var desired_distance: float = DESIRED_DISTANCE
@export var angle_speed: float = 1.0 # radians/second
@export var orbit_angle: float = 0.0 # track this over time
@export var orbit_radius: float = 20.0
var time_elapsed: float = 0

var vel_vertical: float = 0

@onready var scene_root = get_parent().get_parent()


func _ready() -> void:
	print_debug("BossCore ready")
	randomize()
	apply_risk_modifier()
	# If the player has beaten all bosses, buff them for the replay value
	if GameManager.all_bosses_defeated:
		health_component.max_health *= 2
		health_component.initialize_health()
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)
	debug_trajectory_mesh = MeshInstance3D.new()
	debug_trajectory_mesh.mesh = ImmediateMesh.new()
	scene_root.add_child.call_deferred(debug_trajectory_mesh)
	#debug_mesh.visible = false
	for elem in elemental_emitting_vfx:
		if elem:
			elem.visible = false

	# Cheat/debug flags
	if GameManager.CHEAT_oneshot:
		health_component.max_health = 1
		health_component.current_health = 1

	if owner:
		await owner.ready
	print_debug("BossCore ready end")
	

func _physics_process(delta: float) -> void:
	vel_vertical -= GRAVITY * delta
	vel_vertical = clamp(vel_vertical, -MAX_FALL_SPEED, 10000)
	velocity.y = vel_vertical
	move_and_slide()

	# DEBUG
	# TODO - add export var for burning status length so we can configure it
	# per boss/effect
	#if Input.is_action_just_pressed("input_1"):
		#apply_status(BossStatusEffect.BURNING, 5.0)
	#if Input.is_action_just_pressed("input_2"):
		#apply_status(BossStatusEffect.POISONED, 12.0)


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


func orbit_player(delta: float) -> void:
	orbit_pos(target.global_position, delta)


func orbit_pos(pos: Vector3, delta: float, invert: bool = false) -> void:
	orbit_angle += angle_speed * delta
	# offset in XZ-plane
	var offset_x: float
	var offset_z: float
	if invert:
		offset_x = -cos(orbit_angle) * desired_distance
		offset_z = -sin(orbit_angle) * desired_distance
	else:
		offset_x = cos(orbit_angle) * desired_distance
		offset_z = sin(orbit_angle) * desired_distance
	var orbit_pos = pos + Vector3(offset_x, 0, offset_z)
	# Pathfind to orbit_pos
	navigation_component.set_nav_target_position(orbit_pos)


func orbit_towards_player(
	delta: float, approach_speed: float = 1.0, min_radius: float = 10.0
) -> void:
	orbit_angle += angle_speed * delta
	
	orbit_radius -= approach_speed * delta
	if min_radius:
		orbit_radius = max(orbit_radius, min_radius)
	
	# offset in XZ-plane
	var offset_x = cos(orbit_angle) * orbit_radius
	var offset_z = sin(orbit_angle) * orbit_radius
	var orbit_pos = target.global_position + Vector3(offset_x, 0, offset_z)
	# Pathfind to orbit_pos
	navigation_component.set_nav_target_position(orbit_pos)


func fire_projectile(_projectile_prefab: PackedScene, spawn_pos: Vector3, sfx_arr: Array = []) -> Area3D:
	var _sfx_player = get_available_sfx_player()
	if not _sfx_player:
		# TODO - error handling
		pass
	if sfx_arr:
		_sfx_player.stream = sfx_arr.pick_random()
		_sfx_player.play()
	# TODO - pool this
	var projectile := _projectile_prefab.instantiate()
	scene_root.add_child(projectile)
	projectile.global_position = spawn_pos
	projectile.look_at(target.global_position, Vector3.UP)
	return projectile


func activate() -> void:
	print_debug("BossCore activate called")
	show_health()
	SoundManager.play_sound(sfx_awaken, "SFX")

func apply_risk_modifier():
	health_component.max_health *= GameManager.get_risk_max_hp_mult()
	health_component.initialize_health()
	for key in status_resist.keys():
		status_resist[key] *= GameManager.get_risk_status_resist_mult()


## GENERIC STATE HELPERS
func _targeting_entered(next_state: String, attack_name: String = "", delay: float = attack_targeting_time) -> void:
	debug_state_label.text = "%s | Targeting" % attack_name

	state_chart.send_event("start_targeting")
	state_chart.send_event("attack_buildup")
	await get_tree().create_timer(delay).timeout
	state_chart.send_event(next_state)

func _telegraph_attack(_attack_name: String = "") -> void:
	state_chart.send_event("attack_telegraph")
	await get_tree().create_timer(telegraph_time).timeout
	state_chart.send_event("attack_start")
	return

func _recover_entered() -> void:
	state_chart.send_event("attack_end")

	await get_tree().create_timer(attack_recovery_time).timeout

	state_chart.send_event("cooldown_end")
	select_attack()
	# Reset the current state to Targeting
	state_chart.send_event("end_recovery")


func draw_debug_sphere(location: Vector3, size: float, color: Color) -> MeshInstance3D:
	# Will usually work, but you might need to adjust this.
	var another_scene_root = get_tree().root.get_children()[8]
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
	another_scene_root.add_child.call_deferred(node)
	node.global_transform.origin = location

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
	if fallback_player:
		fallback_player.stop()

		return fallback_player
	return null


func play_positional_sound(stream: AudioStream) -> AudioStreamPlayer3D:
	var _player: AudioStreamPlayer3D = get_available_sfx_player()
	
	if not _player:
		return
	
	_player.stream = stream
	_player.play()
	
	return _player


func drop_barrel(target_pos: Vector3 = target.global_position) -> void:
	# Check if we've already given the player this barrel
	if barrel_to_drop in GameManager.inventory_barrels or barrel_to_drop in GameManager.equipped_barrels:
		push_warning("Barrel [%s] already collected, exiting level." % barrel_to_drop.barrel_name)
		# If we don't have a barrel to spawn, emit the signal to end the level
		defeated.emit(self)
		return

	if barrel_pickup_scene == null:
		push_warning("No barrel to spawn.")
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
	var goal_pos: Vector3 = start_pos.lerp(target_pos, 0.7)

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

	# Calculate bezier control points
	var out_0 = (mid_point - start_pos) * 0.6667
	var in_1 = (mid_point - goal_pos) * 0.6667
	curve.add_point(start_pos, Vector3.ZERO, out_0)
	curve.add_point(goal_pos, in_1, Vector3.ZERO)
	path.curve = curve

	# Add the path to the scene
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
		3:
			select_attack_phase_3()
		_:
			push_error("Invalid phase %s" % current_phase)


func select_attack_phase_1() -> void:
	pass


func select_attack_phase_2() -> void:
	pass


func select_attack_phase_3() -> void:
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
	anim_player.play("death")

	await anim_player.animation_finished
	anim_player.process_mode = Node.PROCESS_MODE_DISABLED

	sprite.modulate = Color.DARK_SLATE_BLUE
	death_anim_finished.emit()

#### Revival
func _on_health_idle_state_entered() -> void:
	sprite.modulate = Color.WHITE

### ATTACKING --------------------------------
#### TELEGRAPH
func _on_attack_telegraph_state_entered() -> void:
	sprite.modulate = Color.CYAN


func _on_attack_telegraph_state_exited() -> void:
	sprite.modulate = Color.WHITE


## ======== Signal Callback Methods ========

func _on_stagger() -> void:
	# Play a hurt frame when we do enough DPS
	# TODO - let this interrupt/restart the attack telegraph for some attacks
	if hurt_sprite:
		if hurt_frame_timer.is_stopped() and hurt_frame_cooldown_timer.is_stopped():
			sprite.texture = hurt_sprite
			hurt_frame_timer.start(hurt_frame_window)


func _on_health_changed(new_health: float, prev_health: float) -> void:
	if new_health < prev_health:
		state_chart.send_event("start_damage")
		hurt_sfx_player.stream = sfx_hit.pick_random()
		hurt_sfx_player.pitch_scale = randf_range(0.7, 1.2)
		hurt_sfx_player.play()

		dps_accumulated_in_window += abs(prev_health - new_health)
		if dps_accumulated_in_window > chip_spawn_dps_threshold:
			_on_stagger()
			# Increase chip spawn rate based on DPS
			var chip_mult = snapped(dps_accumulated_in_window / chip_spawn_dps_threshold, 1)
			chip_mult = min(chip_mult, chip_spawn_mult_cap)
			chip_mult = chip_mult * GameManager.get_boss_chip_amount_drop_multiplier()
			print("DPS dealt: %s | chips spawned: %s" % [dps_accumulated_in_window, chip_mult])
			if chip_scene:
				for i in chip_mult:
					if randf() < chip_spawn_chance:
						continue
					var chip = chip_scene.instantiate() as RigidBody3D
					scene_root.add_child(chip)
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


func _on_hurtbox_body_entered(_body: Node3D) -> void:
	pass


func _on_dps_window_timer_timeout() -> void:
	# TODO - check for chip spawn threshold
	dps_accumulated_in_window = 0.0


func _on_hurt_frame_timer_timeout() -> void:
	sprite.texture = base_sprite
	hurt_frame_cooldown_timer.start(hurt_frame_cooldown)


## STATUS EFFECTS

func toggle_emitting_elemental_vfx(status: BossStatusEffect, is_on: bool = true):
	if elemental_emitting_vfx.size() == 0:
		return
	
	var element_vfx_node = elemental_emitting_vfx[int(status) - 1]
	if element_vfx_node:
		element_vfx_node.visible = is_on
		if is_on:
			if element_vfx_node.has_method("turn_on"):
				element_vfx_node.turn_on()
		else:
			if element_vfx_node.has_method("turn_off"):
				element_vfx_node.turn_off()


func apply_status_buildup(status: BossStatusEffect, amount: float) -> void:
	if current_status_buildup[status] < status_resist[status]:
		current_status_buildup[status] += amount
		if current_status_buildup[status] >= status_resist[status]:
			apply_status(status, status_duration[status])

func apply_status(status: BossStatusEffect, duration: float) -> void:
	toggle_emitting_elemental_vfx(status, true)
	var event_string: String = "status_%s" % BossStatusEffect.keys()[status].to_lower()
	state_chart.send_event("add_" + event_string)
	await get_tree().create_timer(duration).timeout
	remove_status(status)

func remove_status(status: BossStatusEffect) -> void:
	status_resist[status] += increased_status_tolerance[status] * GameManager.get_risk_status_resist_mult()
	current_status_buildup[status] = 0
	var event_string: String = "status_%s" % BossStatusEffect.keys()[status].to_lower()
	state_chart.send_event("remove_" + event_string)
	toggle_emitting_elemental_vfx(status, false)


# ====================== Status ==========================
func _on_status_burning_active_state_entered() -> void:
	health_ui.change_status_label_visibility(BossStatusEffect.BURNING, true)
	# TODO - add burning effect particles/shader/icon
	#
	burning_timer.start(0.5) # Interval between damage


func _on_status_burning_active_state_physics_processing(_delta: float) -> void:
	pass


func _on_status_burning_active_state_exited() -> void:
	health_ui.change_status_label_visibility(BossStatusEffect.BURNING, false)
	burning_timer.stop()


func _on_status_poisoned_active_state_entered() -> void:
	health_ui.change_status_label_visibility(BossStatusEffect.POISONED, true)
	poisoned_timer.start(2.5) # Interval between damage


func _on_status_poisoned_active_state_physics_processing(_delta: float) -> void:
	pass


func _on_status_poisoned_active_state_exited() -> void:
	health_ui.change_status_label_visibility(BossStatusEffect.POISONED, false)
	poisoned_timer.stop()


func _on_status_frozen_active_state_entered() -> void:
	health_ui.change_status_label_visibility(BossStatusEffect.FROZEN, true)


func _on_status_frozen_active_state_exited() -> void:
	health_ui.change_status_label_visibility(BossStatusEffect.FROZEN, false)

func _on_status_frozen_active_state_physics_processing(_delta: float) -> void:
	# TODO: Implement frozen effect
	pass

func _on_status_bleeding_active_state_entered() -> void:
	health_ui.change_status_label_visibility(BossStatusEffect.BLEEDING, true)
	take_bleed_burst_damage()

func _on_status_bleeding_active_state_physics_processing(_delta: float) -> void:
	pass

func _on_status_bleeding_active_state_exited() -> void:
	health_ui.change_status_label_visibility(BossStatusEffect.BLEEDING, false)


func _on_status_shocked_active_state_entered() -> void:
	health_component.received_dmg_multiplier += SHOCKED_DMG_MULTIPLIER
	health_ui.change_status_label_visibility(BossStatusEffect.SHOCKED, true)

func _on_status_shocked_active_state_exited() -> void:
	health_component.received_dmg_multiplier -= SHOCKED_DMG_MULTIPLIER
	health_ui.change_status_label_visibility(BossStatusEffect.SHOCKED, false)

func _on_status_shocked_active_state_physics_processing(_delta: float) -> void:
	pass


func take_bleed_burst_damage() -> void:
	# Take 4% max hp damage and 100 flat damage
	const BLEED_DMG_MAX_HP_PERC = 0.04
	const BLEED_DMG_FLAT = 100
	var bleed_dmg = int(health_component.max_health * BLEED_DMG_MAX_HP_PERC + BLEED_DMG_FLAT)
	health_component.damage(bleed_dmg, Color.DARK_RED)
	sprite.modulate = Color.DARK_RED
	await get_tree().create_timer(0.2).timeout
	sprite.modulate = Color.WHITE


func _on_burning_timer_timeout() -> void:
	const BURN_DMG_MAX_HP_PERC_PER_TICK = 0.003
	const BURN_DMG_FLAT_PER_TICK = 25
	# (0.3% max hp dmg per tick and flat 25)
	# With 20 ticks, 6% max hp and 500 flat damage
	var burn_dmg = int(health_component.max_health * BURN_DMG_MAX_HP_PERC_PER_TICK + BURN_DMG_FLAT_PER_TICK)
	health_component.damage(burn_dmg, Color.ORANGE)
	sprite.modulate = Color.ORANGE
	await get_tree().create_timer(0.2).timeout
	sprite.modulate = Color.WHITE


func _on_poisoned_timer_timeout() -> void:
	const POISON_DMG_MAX_HP_PERC_PER_TICK = 0.02
	const POISON_DMG_FLAT_PER_TICK = 140
	# (2% max hp dmg per tick and flat 140)
	# With 4 ticks, 8% max hp and 560 flat damage
	var poison_dmg = int(health_component.max_health * POISON_DMG_MAX_HP_PERC_PER_TICK + POISON_DMG_FLAT_PER_TICK)
	health_component.damage(poison_dmg, Color.WEB_GREEN)
	sprite.modulate = Color.WEB_GREEN
	await get_tree().create_timer(0.2).timeout
	sprite.modulate = Color.WHITE


## Attack spawn helpers
#
## DECALS
func spawn_decal_at_pos(pos: Vector3, texture: CompressedTexture2D, size: Vector3 = Vector3(0, 1, 0)) -> Decal:
	var _decal := _create_decal(texture, size)
	scene_root.add_child(_decal)
	_decal.global_position = pos
	return _decal

func _create_decal(texture: CompressedTexture2D, size: Vector3 = Vector3(0, 1, 0)) -> Decal:
	var _decal := Decal.new()
	_decal.cull_mask = 1
	_decal.texture_albedo = texture
	_decal.size = size
	return _decal

func _cleanup_aoe_decals(decals_to_remove: Array) -> void:
	for decal in decals_to_remove:
		decal.queue_free()
