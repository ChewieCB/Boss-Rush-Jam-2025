extends BaseBossProjectile
class_name DiamondProjectile

@onready var homing_delay_timer: Timer = $HomingDelay
@onready var homing_timer: Timer = $HomingTimer

@export var rotation_speed: float = 25.0
@export var homing_delay: float = 0.15
@export var homing_time: float = 0.3

var target: CharacterBody3D
var velocity: Vector3
var rot: Vector3

func _ready() -> void:
	super ()
	homing_delay_timer.start(homing_delay)
	homing_timer.start(homing_time)

func init(_damage: float, _speed: float):
	projectile_damage = _damage
	projectile_speed = _speed

func _physics_process(delta: float) -> void:
	if homing_delay_timer.is_stopped() and not homing_timer.is_stopped():
		var direction = target.global_transform.origin - global_transform.origin
		direction = direction.normalized()
		var rotation_amount: Vector3 = direction.cross(global_transform.basis.z)
		rot.y = rotation_amount.y * rotation_speed * delta
		rot.x = rotation_amount.x * rotation_speed * delta
		rotate(Vector3.UP, rot.y)
		rotate(Vector3.RIGHT, rot.x)

		global_translate(-global_transform.basis.z * projectile_speed * delta)
	else:
		global_position -= transform.basis.z * projectile_speed * delta

func _on_homing_delay_timeout() -> void:
	homing_timer.start(homing_delay)
