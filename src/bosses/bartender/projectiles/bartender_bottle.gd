extends RigidBody3D
class_name BartenderBottle

@export var break_effect_prefab: PackedScene
@export var spark_effect: PackedScene
@export var break_on_contact = true
@export var sfx_break: Array[AudioStream]
@export var sfx_bounce: Array[AudioStream]

@onready var life_timer: Timer = $LifeTimer
@onready var sfx_player: AudioStreamPlayer3D = $SFXPlayer

var damage
var projectile_speed = 100
var current_dir
var bartender_owner: BossCore

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

	create_spark(global_position, -current_dir)
	spawn_break_effect()
	
	if break_on_contact:
		visible = false
		sfx_player.stream = sfx_break.pick_random()
		sfx_player.play()
		await sfx_player.finished
		call_deferred("queue_free")
	else:
		sfx_player.stream = sfx_bounce.pick_random()
		sfx_player.play()

func spawn_break_effect():
	if break_effect_prefab == null:
		return
	var inst = break_effect_prefab.instantiate()
	# Spawn in world environment
	GameManager.player.get_parent().add_child(inst)
	inst.position = global_position - current_dir
	bartender_owner.health_component.died.connect(inst.queue_free)

func create_spark(pos: Vector3, normal: Vector3):
	if spark_effect == null:
		return

	var spark_inst = spark_effect.instantiate()
	get_parent().add_child(spark_inst)
	spark_inst.global_position = pos

	if normal.is_equal_approx(Vector3.DOWN):
		spark_inst.rotation_degrees.x = -90
	elif normal.is_equal_approx(Vector3.UP):
		spark_inst.rotation_degrees.x = 90
	else:
		spark_inst.look_at(pos + normal, Vector3.UP)
