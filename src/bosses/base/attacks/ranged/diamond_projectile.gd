extends BaseBossProjectile
class_name DiamondProjectile


## How sharp it can rotate to homing
@export var rotation_speed: float = 10.0
## How long before it start to homing toward target.
@export var homing_delay: float = 0.3
## How long it keep homing at target. When this end, it fly straight as normal.
@export var homing_time: float = 0.5

@onready var homing_delay_timer: Timer = $HomingDelay
@onready var homing_timer: Timer = $HomingTimer
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var is_homing = false
var target: CharacterBody3D
var velocity: Vector3
var rot: Vector3
var diamond_homing_speed = projectile_speed

func _ready() -> void:
	super ()
	homing_delay_timer.start(homing_delay)

func init(_damage: float, _speed: float):
	projectile_damage = _damage
	projectile_speed = _speed

func _physics_process(delta: float) -> void:
	if is_homing:
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
	homing_timer.start(homing_time)
	projectile_speed = diamond_homing_speed
	is_homing = true
	var anim_speed = [-1, 1].pick_random()
	anim_player.speed_scale = anim_speed
	anim_player.play("spin")


func _on_homing_timer_timeout() -> void:
	is_homing = false
	anim_player.stop()
