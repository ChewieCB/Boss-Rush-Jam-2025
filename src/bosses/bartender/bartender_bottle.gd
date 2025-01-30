extends RigidBody3D

@export var break_effect_prefab: PackedScene
@export var break_on_contact = true
@export var break_sfx: AudioStream

@onready var life_timer: Timer = $LifeTimer

var damage
var projectile_speed = 100
var current_dir

func init(start_pos: Vector3, dir: Vector3, _damage: int, _speed: float):
	life_timer.start()
	projectile_speed = _speed
	damage = _damage
	current_dir = dir.normalized()
	look_at_from_position(start_pos, start_pos + dir)

	await get_tree().physics_frame
	await get_tree().physics_frame

	apply_impulse(current_dir * projectile_speed, Vector3.ZERO)


func _on_life_timer_timeout() -> void:
	spawn_break_effect()
	call_deferred("queue_free")

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		body.health_component.damage(damage)
	else:
		if body is Shield:
			body.impact(self.global_position)
			body.health_component.damage(damage)
		elif body is RouletteBall:
			body.health_component.damage(damage)

	spawn_break_effect()
	if break_on_contact:
		SoundManager.play_sound(break_sfx, "SFX")
		call_deferred("queue_free")

func spawn_break_effect():
	if break_effect_prefab == null:
		return
	var inst = break_effect_prefab.instantiate()
	# Spawn in world environment
	GameManager.player.get_parent().add_child(inst)
	inst.position = global_position - current_dir