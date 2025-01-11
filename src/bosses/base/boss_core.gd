extends CharacterBody3D
class_name BossCore

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

@export var attack_recovery_time: float = 0.5

# Make sure the boss doesn't spam attacks
# TODO - make this more modular
var max_sequential_phases: int = 3
var charge_phase_count: int = 0
var ranged_phase_count: int = 0
var area_phase_count: int = 0

# Charge Attack
# TODO - make this adjustable via resources
@export var charge_telegraph_time: float = 0.25

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

@onready var hurtbox: Area3D = $Hurtbox
@onready var health_ui = $UI/HealthUI/BossHealthContainer

var MAX_SPEED: float = 5.0
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
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)
	#debug_mesh.visible = false
	await owner.ready
	ranged_move_points = get_tree().get_nodes_in_group("boss_ranged_marker")
	area_move_points = get_tree().get_nodes_in_group("boss_area_marker")


func _physics_process(delta: float) -> void:
	vel_vertical -= GRAVITY * delta
	vel_vertical = clamp(vel_vertical, -MAX_FALL_SPEED, 10000)
	velocity.y = vel_vertical

	move_and_slide()
	debug_dist_label.text = "(%su)" % [
		round(self.global_position.distance_to(target.global_position))
	]


func jump(multiplier = 1.0):
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


func change_phase() -> void:
	var dist_to_target = self.global_position.distance_to(target.global_position)
	var possible_phases = [
		"start_chase_attack",
		"start_ranged_attack",
		"start_area_attack"
	]
	if ranged_phase_count == max_sequential_phases:
		possible_phases.erase("start_ranged_attack")
		ranged_phase_count = 0
	if charge_phase_count == max_sequential_phases:
		possible_phases.erase("start_chase_attack")
		charge_phase_count = 0
	if area_phase_count == max_sequential_phases:
		possible_phases.erase("start_area_attack")
		area_phase_count = 0
	
	# If we've somehow exluded all of the possible phases, 
	# the counters have been reset so just call this method again.
	if possible_phases == []:
		change_phase()
		return
	
	# If the player is too close, don't do area attacks
	if dist_to_target <= area_size / 2:
		possible_phases.erase("start_area_attack")
	else:
		#possible_phases.erase("start_area_attack")
		possible_phases.append("start_area_attack")
	
	# If the player is further away, prioritise charges and area attacks
	if dist_to_target >= 30:
		possible_phases.append("start_chase_attack")
		possible_phases.append("start_chase_attack")
		possible_phases.append("start_chase_attack")
	# If the player is closer, prioritise ranged attacks
	else:
		possible_phases.append("start_ranged_attack")
		possible_phases.append("start_ranged_attack")
		possible_phases.append("start_ranged_attack")
		possible_phases.append("start_area_attack")
	
	var new_phase: String = possible_phases[randi_range(0, possible_phases.size() - 1)]
	state_chart.send_event(new_phase)


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
		velocity.x = lerp(velocity.x, 0.0, delta)
	if velocity.z > 0.0:
		velocity.z = lerp(velocity.z, 0.0, delta)

#### TARGETING
func _on_movement_targeting_state_entered() -> void:
	navigation_component.disable()

func _on_movement_targeting_state_physics_processing(delta: float) -> void:
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


func _on_hurtbox_body_entered(body: Node3D) -> void:
	SoundManager.play_sound(TEMP_sfx_charge_impact)
	if body == target:
		target.health_component.damage(40)
