extends Area3D

@export var damage: int = 5
@export var speed: float = 5.0
@export var rise_speed: float = 0

var current_dir: Vector3

func init(start_pos: Vector3, dir: Vector3) -> void:
	position = start_pos
	current_dir = dir
	look_at_from_position(start_pos, start_pos + current_dir)

func _physics_process(delta: float) -> void:
	global_position -= (transform.basis.z * speed + Vector3(0, -rise_speed, 0)) * delta

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		var player: Player = body
		player.health_component.damage(damage)

	queue_free()


func _on_life_timer_timeout() -> void:
	queue_free()
