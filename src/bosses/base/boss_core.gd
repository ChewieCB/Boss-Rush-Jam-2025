extends CharacterBody3D
class_name BossCore

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

# Point Movement
@export var move_points: Array[Marker3D]

@onready var hurtbox: Area3D = $Hurtbox
@onready var health_ui = $BossHealthUI/BossHealthContainer

var MAX_SPEED: float = 5.0
const TURN_SPEED_FAST: float = 7.5
const TURN_SPEED_SLOW: float = 5.0
const MAX_FALL_SPEED: float = 50.0
const ACCEL_RATE: float = 40.0
const JUMP_FORCE: float = 8
const GRAVITY: float = 14

var vel_vertical: float = 0


@export var target: Node3D:
	set(value):
		target = value
		if not target.is_node_ready():
			await target.ready
		navigation_component.target = target
var cached_target: Node3D

func _ready() -> void:
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)
	#debug_mesh.visible = false


func _physics_process(delta: float) -> void:
	vel_vertical -= GRAVITY * delta
	vel_vertical = clamp(vel_vertical, -MAX_FALL_SPEED, 10000)
	velocity.y = vel_vertical
	
	move_and_slide()
	debug_dist_label.text = "(%su)" % [
		round(self.global_position.distance_to(target.global_position))
	]


func _turn_towards_target(speed: float, delta: float) -> void:
	var direction: Vector3 = self.global_position.direction_to(target.global_position)
	self.rotation.y = lerp_angle(
		self.rotation.y,atan2(
			-direction.x, -direction.z
		),
		delta * speed
	)


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

func _on_movement_charging_state_physics_processing(delta: float) -> void:
	velocity.x = lerp(velocity.x, 0.0, 0.08)
	velocity.z = lerp(velocity.z, 0.0, 0.08)
	
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
	sprite.modulate = Color.CYAN


func _on_attack_telegraph_state_exited() -> void:
	sprite.modulate = Color.WHITE


## ======== Signal Callback Methods ========

func _on_health_changed(new_health: float, prev_health: float) -> void:
	if new_health < prev_health:
		state_chart.send_event("start_damage")
		if prev_health == health_component.max_health:
			# TODO - replace with function to decide which attack to do
			var phase_chance: float = randf()
			if phase_chance < 0.5:
				state_chart.send_event("start_chase_attack")
			else:
				state_chart.send_event("start_ranged_attack")


func _on_died() -> void:
	state_chart.send_event("death")
	state_chart.send_event("stop_moving")
	state_chart.send_event("deactivate")


func _on_hurtbox_body_entered(body: Node3D) -> void:
	if body == target:
		target.health_component.damage(40)


### ATTACK PHASES --------------------------------
#### INACTIVE
func _on_phase_inactive_state_entered() -> void:
	debug_state_label.text = "Inactive"
	sprite.modulate = Color.DIM_GRAY


#### CHASE PLAYER
func _on_phase_target_player_state_entered() -> void:
	sprite.modulate = Color.WHITE
	debug_state_label.text = "Chase | Targeting"
	
	state_chart.send_event("start_targeting")
	await get_tree().create_timer(2.0).timeout
	state_chart.send_event("attack_telegraph")
	await get_tree().create_timer(charge_telegraph_time).timeout
	state_chart.send_event("attack_start")
	state_chart.send_event("charge_player")

func _on_phase_chase_player_charge_state_entered() -> void:
	sprite.modulate = Color.ORANGE
	debug_state_label.text = "Chase | Charging"
	state_chart.send_event("start_charge")

func _on_phase_chase_player_recover_state_entered() -> void:
	sprite.modulate = Color.YELLOW
	debug_state_label.text = "Chase | Recovering"
	state_chart.send_event("attack_end")
	await get_tree().create_timer(attack_recovery_time).timeout
	
	state_chart.send_event("cooldown_end")
	charge_phase_count += 1
	change_phase()
	state_chart.send_event("end_recovery")


#func _on_phase_chase_player_recover_state_exited() -> void:
	#sprite.modulate = Color.WHITE


#### RANGED PROJECTILES
func _on_phase_ranged_projectiles_move_to_center_state_entered() -> void:
	sprite.modulate = Color.YELLOW
	debug_state_label.text = "Projectiles | Moving"
	
	MAX_SPEED *= 2
	
	var valid_move_points = move_points.duplicate()
	valid_move_points.sort_custom(
		func(a, b):
			var a_dist: float = self.global_position.distance_to(a.global_position)
			var b_dist: float = self.global_position.distance_to(b.global_position)
			if a_dist < b_dist:
				return true
			return false
	)
	valid_move_points.pop_front()
	
	cached_target = target
	target = valid_move_points[0]
	state_chart.send_event("start_moving")
	
	await navigation_component.nav_agent.navigation_finished
	state_chart.send_event("start_projectiles")

func _on_phase_ranged_projectiles_move_to_center_state_exited() -> void:
	target = cached_target
	MAX_SPEED /= 2

func _on_phase_ranged_projectiles_fire_projectiles_state_entered() -> void:
	sprite.modulate = Color.ORANGE
	debug_state_label.text = "Projectiles | Firing"
	
	state_chart.send_event("start_targeting")
	
	for i in projectiles_per_phase:
		await get_tree().create_timer(delay_per_projectile).timeout
		var projectile: TestProjectile = projectile_scene.instantiate()
		get_parent().get_parent().add_child(projectile)
		projectile.global_position = self.global_position + Vector3(0, 3, 0)
		projectile.look_at(target.global_position, Vector3.UP)
	
	await get_tree().create_timer(delay_per_projectile).timeout
	state_chart.send_event("end_projectiles")

func _on_phase_ranged_projectiles_recover_state_entered() -> void:
	sprite.modulate = Color.YELLOW
	debug_state_label.text = "Projectiles | Recovering"
	
	state_chart.send_event("attack_end")
	projectile_round_count += 1
	await get_tree().create_timer(attack_recovery_time).timeout
	state_chart.send_event("cooldown_end")
	
	if projectile_round_count < max_projectile_rounds:
		var fire_again_chance: float = randf()
		if fire_again_chance < 0.55:
			state_chart.send_event("fire_again")
			return
	
	ranged_phase_count += 1
	change_phase()
	state_chart.send_event("change_position")


func change_phase() -> void:
	if ranged_phase_count == max_sequential_phases:
		state_chart.send_event("start_chase_attack")
		ranged_phase_count = 0
	elif charge_phase_count == max_sequential_phases:
		state_chart.send_event("start_ranged_attack")
		charge_phase_count = 0
	elif self.global_position.distance_to(target.global_position) >= 20:
		if randf() < 0.75:
			state_chart.send_event("start_chase_attack")
		else:
			state_chart.send_event("start_ranged_attack")
	else:
		if randf() < 0.65:
			state_chart.send_event("start_ranged_attack")
		else:
			state_chart.send_event("start_chase_attack")
