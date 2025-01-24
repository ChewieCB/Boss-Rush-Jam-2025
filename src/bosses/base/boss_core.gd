extends CharacterBody3D
class_name BossCore

signal defeated(boss: BossCore)

@export_category("Barrels")
@export var barrel_to_drop: BarrelDataResource
@export var barrel_pickup_scene: PackedScene
var debug_trajectory_mesh: MeshInstance3D

## TEMP SFX REPLACE THESE
@export var TEMP_sfx_awaken: AudioStream
@export var TEMP_sfx_hit: Array[AudioStream]
@export var TEMP_sfx_death: AudioStream
@export var TEMP_sfx_area_1: AudioStream
@export var TEMP_sfx_area_2: AudioStream
@export var TEMP_sfx_projectile: AudioStream
@export var TEMP_sfx_telegraph: AudioStream
@export var TEMP_sfx_charge: AudioStream
@export var TEMP_sfx_charge_impact: AudioStream

@export var navigation_component: NavigationComponent
@export var health_component: HealthComponent

@onready var sprite: Sprite3D = $Sprite3D
@onready var debug_mesh: MeshInstance3D = $DebugMesh
@onready var debug_state_label: Label3D = $DebugStateLabel
@onready var debug_dist_label: Label3D = $DebugDistanceLabel
@onready var state_chart: StateChart = $StateChart

@export var current_phase: int = 1

@export var attack_recovery_time: float = 0.5

# Make sure the boss doesn't spam attacks
# TODO - make this more modular
var max_sequential_phases: int = 3
var charge_phase_count: int = 0
var ranged_phase_count: int = 0
var area_phase_count: int = 0

# Charge Attack
# TODO - make this adjustable via resources
@export var telegraph_time: float = 0.25

# Projectile Attack
# TODO - make this adjustable via resources
@export var projectile_scene: PackedScene
@export var projectiles_per_phase: int = 5
@export var delay_per_projectile: float = 0.6
var projectile_round_count: int = 0
@export var max_projectile_rounds: int = 2

var ranged_move_points: Array[Node]
var area_move_points: Array[Node]

# Area Attack
# TODO - make this adjustable via resources
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

@export var MAX_SPEED: float = 5.0
@export var FRICTION: float = 1.0
const TURN_SPEED_FAST: float = 7.5
const TURN_SPEED_SLOW: float = 5.0
const MAX_FALL_SPEED: float = 50.0
const ACCEL_RATE: float = 40.0
const JUMP_FORCE: float = 8
var GRAVITY: float = 14

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
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)
	debug_trajectory_mesh = MeshInstance3D.new()
	debug_trajectory_mesh.mesh = ImmediateMesh.new()
	get_tree().get_root().add_child(debug_trajectory_mesh)
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
		self.rotation.y,atan2(
			-direction.x, -direction.z
		),
		delta * speed
	)


func activate() -> void:
	show_health()
	SoundManager.play_sound(TEMP_sfx_awaken)


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
	var goal_dir: Vector3 = start_pos.direction_to(target.global_position)
	var goal_dist: float = start_pos.distance_to(target.global_position)
	var goal_pos: Vector3 = goal_dir * goal_dist * 0.65
	
	# Snap to floor
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		goal_pos, 
		goal_pos - Vector3(0, 100, 0),
		pow(2, 1-1) + pow(2, 7-1)
	)
	var result = space_state.intersect_ray(query)
	goal_pos.y = result.position.y + 1.5
	
	# Generate path to follow
	var path = Path3D.new()
	var curve = Curve3D.new()
	var mid_point: Vector3 = goal_dir * goal_dist * 0.4 + Vector3(0, 5.0, 0)
	
	# Calculate bezier control points
	var out_0 = (mid_point - start_pos) * 0.6667
	var in_1 = (mid_point - goal_pos) * 0.6667
	curve.add_point(start_pos, Vector3.ZERO, out_0)
	curve.add_point(goal_pos, in_1, Vector3.ZERO)
	path.curve = curve
	
	# Add the path to the scene
	get_tree().get_root().add_child(path)
	path.global_position = self.global_position
	var path_follow = PathFollow3D.new()
	path.add_child(path_follow)
	
	# Add the barrel to the path
	path_follow.add_child(barrel)
	barrel.global_position = path_follow.global_position
	
	# Connect the barrel pickup to the end of the level
	barrel.collected.connect(_on_barrel_collected)
	barrel.collected.connect(
		func():
			get_tree().get_root().remove_child(path)
			path.queue_free()
	)
	
	# Throw the barrel towards the player in an arc using kinematics
	var tween = get_tree().create_tween()
	tween.tween_property(path_follow, "progress_ratio", 1.0, 1.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)


func _on_barrel_collected(data: BarrelDataResource) -> void:
	# TODO - show UI with new barrel effects
	#
	# Wait for player to click continue
	#
	defeated.emit(self)


func select_attack() -> void:
	match current_phase:
		1:
			select_attack_phase_1()
		_:
			push_error("Invalid phase %s" % current_phase)


func select_attack_phase_1() -> void:
	pass



func _exit_tree() -> void:
	for object in spawned_area_objects:
		for node in object:
			if is_instance_valid(node):
				node.queue_free()


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
	var charge_dir = -self.global_basis.z
	var charge_impulse = self.global_position.distance_to(target.global_position) * 8
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
	sprite.modulate = Color.DARK_SLATE_BLUE

### ATTACKING --------------------------------
#### TELEGRAPH
func _on_attack_telegraph_state_entered() -> void:
	SoundManager.play_sound(TEMP_sfx_telegraph)
	sprite.modulate = Color.CYAN


func _on_attack_telegraph_state_exited() -> void:
	sprite.modulate = Color.WHITE


## ======== Signal Callback Methods ========

func _on_health_changed(new_health: float, prev_health: float) -> void:
	if new_health < prev_health:
		state_chart.send_event("start_damage")
		SoundManager.play_sound_with_pitch(TEMP_sfx_hit.pick_random(), randf_range(0.7, 1.2))


func _on_died() -> void:
	state_chart.send_event("death")
	state_chart.send_event("stop_moving")
	state_chart.send_event("deactivate")
	drop_barrel()


func _on_hurtbox_body_entered(body: Node3D) -> void:
	SoundManager.play_sound(TEMP_sfx_charge_impact)
	if body == target:
		target.health_component.damage(40)
