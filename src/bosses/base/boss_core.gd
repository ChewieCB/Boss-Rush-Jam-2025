extends CharacterBody3D
class_name BossCore

@export var navigation_component: NavigationComponent
@export var health_component: HealthComponent

@onready var sprite: Sprite3D = $Sprite3D
@onready var debug_mesh: MeshInstance3D = $DebugMesh
@onready var debug_state_label: Label3D = $DebugStateLabel
@onready var state_chart: StateChart = $StateChart

@onready var hurtbox: Area3D = $Hurtbox
@onready var health_ui = $BossHealthUI/BossHealthContainer

const MAX_SPEED: float = 5.0
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


func _ready() -> void:
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)
	#debug_mesh.visible = false


func _physics_process(delta: float) -> void:
	vel_vertical -= GRAVITY * delta
	vel_vertical = clamp(vel_vertical, -MAX_FALL_SPEED, 10000)
	velocity.y = vel_vertical
	
	move_and_slide()


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
	var charge_impulse = self.global_position.distance_to(target.global_position) * 6
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
			state_chart.send_event("start_chase_attack")


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
	await get_tree().create_timer(0.15).timeout
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
	await get_tree().create_timer(1.2).timeout
	state_chart.send_event("cooldown_end")
	state_chart.send_event("end_recovery")

#func _on_phase_chase_player_recover_state_exited() -> void:
	#sprite.modulate = Color.WHITE
