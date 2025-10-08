extends Area3D
class_name ExplosionDamageArea

@onready var explosion_vfx: Node3D = $ExplosionVFX

const LINGERING_DURATION = 0.1

var damage = 0
var disabled = false

func init(_damage: int):
	damage = _damage

func _ready() -> void:
	if explosion_vfx.time_until_queue_free < LINGERING_DURATION:
		push_warning("Explosion VFX visible duration is less than damage hitbox duration!")

	get_tree().create_timer(LINGERING_DURATION).timeout.connect(func(): disabled = true)
	explosion_vfx.finished.connect(func(): queue_free())


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and not disabled:
		body.health_component.damage(damage, Color.ORANGE)
		if body is Player:
			body.apply_impulse_to_player(global_position.direction_to(body.global_position) * damage)
			# TODO - negative luck from getting hit by your own AoE
		else:
			LuckHandler.accumulate_dps_dealt(damage)
