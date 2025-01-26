extends Area3D
class_name TestProjectile

@onready var timer: Timer = $Timer

@export var projectile_damage: float = 10.0
@export var projectile_speed: float = 50.0

# TODO - rework this using the gun projectile so we can get impacts and ricochets

func _physics_process(delta: float) -> void:
	self.global_position -= transform.basis.z * projectile_speed * delta


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		body.health_component.damage(projectile_damage)
	# TODO - make this have collision exception based on who fired it
	elif body is BossCore:
		pass
	else:
		queue_free()


func _on_timer_timeout() -> void:
	queue_free()
