extends CharacterBody3D
class_name BossCore

@export var navigation_component: NavigationComponent
@export var health_component: HealthComponent

@onready var sprite: Sprite3D = $Sprite3D
@onready var debug_mesh: MeshInstance3D = $DebugMesh
@onready var state_chart: StateChart = $StateChart

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


## ======== Signal Callback Methods ========

func _on_health_changed(new_health: float, prev_health: float) -> void:
	if new_health < prev_health:
		state_chart.send_event("start_damage")


func _on_died() -> void:
	state_chart.send_event("death")
	state_chart.send_event("stop_moving")
