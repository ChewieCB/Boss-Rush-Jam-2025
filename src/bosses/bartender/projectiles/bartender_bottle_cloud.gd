extends Area3D

@export var damage: int = 5
@export var speed: float = 50.0

var current_dir: Vector3

func _physics_process(delta: float) -> void:
	current_dir = - transform.basis.z.normalized()
	global_position -= transform.basis.z * speed * delta

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		var player: Player = body
		player.health_component.damage(damage)

	queue_free()


func _on_life_timer_timeout() -> void:
	queue_free()
