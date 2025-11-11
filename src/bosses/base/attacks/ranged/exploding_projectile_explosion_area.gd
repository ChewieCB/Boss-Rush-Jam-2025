extends Area3D
class_name ExplosionDamageProjectileArea

@export var collider: CollisionShape3D

@export var damage: int = 0
@export var radius: float = 1.0
@export var pushback_scale: float = 1.0


func init(_damage: int, _radius: float, _pushback_scale: float = 1.0):
	self.damage = _damage
	self.pushback_scale = _pushback_scale
	_set_damage_radius(_radius)


func _set_damage_radius(radius: float) -> void:
	self.radius = radius
	var new_shape := SphereShape3D.new()
	new_shape.radius = radius
	collider.shape = new_shape


func query() -> void:
	for body in get_overlapping_bodies():
		if body is CharacterBody3D:
			if body is Player:
				body.apply_impulse_to_player(global_position.direction_to(body.global_position) * damage * pushback_scale)
		if "health_component" in body:
			body.health_component.damage(damage)
