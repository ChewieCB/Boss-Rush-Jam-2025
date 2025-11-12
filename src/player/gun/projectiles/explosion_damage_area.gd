extends Area3D
class_name ExplosionDamageArea

@onready var explosion_vfx: Node3D = $ExplosionVFX
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

const LINGERING_DURATION = 0.1

var active = false
var damage = 0
var damage_disabled = true

func init(_damage: int):
	damage = _damage

func activate(start_pos: Vector3) -> void:
	damage_disabled = false
	global_position = start_pos
	active = true
	visible = true
	collision_shape.call_deferred("set_disabled", false)
	explode()
	process_mode = PROCESS_MODE_INHERIT


func set_damage_radius(radius: float) -> void:
	var new_shape := SphereShape3D.new()
	new_shape.radius = radius
	collision_shape.shape = new_shape


func deactivate() -> void:
	visible = false
	active = false
	damage_disabled = true
	collision_shape.call_deferred("set_disabled", true)
	process_mode = PROCESS_MODE_DISABLED


func explode():
	if explosion_vfx.time_until_queue_free < LINGERING_DURATION:
		push_warning("Explosion VFX visible duration is less than damage hitbox duration!")

	explosion_vfx.explode()
	get_tree().create_timer(LINGERING_DURATION).timeout.connect(func(): damage_disabled = true)
	explosion_vfx.finished.connect(func(): deactivate())

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and not damage_disabled:
		body.health_component.damage(damage, Color.ORANGE)
		if body is Player:
			body.apply_impulse_to_player(global_position.direction_to(body.global_position) * damage)
			# TODO - negative luck from getting hit by your own AoE
		else:
			LuckHandler.accumulate_dps_dealt(damage)
