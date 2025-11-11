extends Area3D
class_name ExplosionDamageArea

@onready var collider: CollisionShape3D = $CollisionShape3D

var damage = 0

const LINGERING_DURATION = 0.1

func init(_damage: int):
	damage = _damage

func _ready() -> void:
	await get_tree().create_timer(LINGERING_DURATION).timeout
	call_deferred("queue_free")


func set_damage_radius(radius: float) -> void:
	var new_shape := SphereShape3D.new()
	new_shape.radius = radius
	collider.shape = new_shape


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		body.health_component.damage(damage, Color.ORANGE)
		if body is Player:
			body.apply_impulse_to_player(global_position.direction_to(body.global_position) * damage)
			# TODO - negative luck from getting hit by your own AoE
		else:
			LuckHandler.accumulate_dps_dealt(damage)
