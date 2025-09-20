extends Area3D

@export var damage: float = 10.0
@export var pushback_force: float = 15.0


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		if not body.is_dashing:
			_pushback_effect(body)


func _pushback_effect(body: Node3D) -> void:
	body.health_component.damage(damage)
	var pushback_vector = Vector3.FORWARD
	
	body.velocity = Vector3.ZERO
	body.vel_horizontal += Vector2(pushback_vector.x, pushback_vector.z) * pushback_force
	body.vel_vertical += pushback_vector.y * pushback_force
