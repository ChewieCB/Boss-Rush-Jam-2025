extends RigidBody3D
class_name BartenderBottle


## Puddle
@export var break_effect_prefab: PackedScene
@export var damage_cloud_prefab: PackedScene
@export var cloud_count: int = 8
@export var spark_effect: PackedScene
@export var break_on_contact = true
@export var sfx_break: Array[AudioStream]
@export var sfx_bounce: Array[AudioStream]

@onready var life_timer: Timer = $LifeTimer
@onready var sfx_player: AudioStreamPlayer3D = $SFXPlayer

var damage = 1
var projectile_speed = 100
var current_dir = Vector3.ZERO
var bartender_owner: BossCore
var start_pos: Vector3

# func init(_start_pos: Vector3, dir: Vector3, _damage: int, _speed: float):
# 	life_timer.start()
# 	start_pos = _start_pos
# 	projectile_speed = _speed
# 	damage = _damage
# 	current_dir = dir.normalized()
# 	look_at_from_position(start_pos, start_pos + dir)

# 	await get_tree().physics_frame
# 	await get_tree().physics_frame

# 	apply_impulse(current_dir * projectile_speed, Vector3.ZERO)

func init_tween(_start_pos: Vector3, end_pos: Vector3, proj_damage: int, peak_height: float) -> void:
	const TRAVEL_DURATION = 1
	damage = proj_damage
	global_position = _start_pos
	var peak = _start_pos + Vector3(0, peak_height, 0)
	var tween = create_tween()
	tween.tween_method(
		func(t):
			global_position = _start_pos.lerp(peak, t).lerp(
				peak.lerp(end_pos, t), t
			),
		0.0,
		1.0,
		TRAVEL_DURATION
	)


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
	if break_effect_prefab != null:
		var inst = break_effect_prefab.instantiate()
		# Spawn in world environment
		GameManager.player.get_parent().add_child(inst)
		inst.global_position = global_position - current_dir # Avoid clipping
		if bartender_owner:
			bartender_owner.health_component.died.connect(inst.queue_free)
			var thrown_dir = global_position - bartender_owner.global_position
			thrown_dir.y = 0
			inst.look_at(global_position + thrown_dir.normalized())

	const CLOUD_ANGLE_RAND = 0.2
	const CLOUD_Y_OFFSET = 0.1

	if damage_cloud_prefab != null:
		for i in range(cloud_count):
			var inst = damage_cloud_prefab.instantiate()
			# Spawn in world environment
			GameManager.player.get_parent().add_child(inst)
			if bartender_owner:
				bartender_owner.health_component.died.connect(inst.queue_free)
			var angle = TAU * i / cloud_count
			angle += randf_range(-CLOUD_ANGLE_RAND, CLOUD_ANGLE_RAND)
			var pos = global_position - current_dir + Vector3(0, CLOUD_Y_OFFSET, 0)
			var dir = Vector3(cos(angle), 0, sin(angle))
			inst.init(pos, dir.normalized())

func create_spark(pos: Vector3, normal: Vector3):
	if spark_effect == null:
		return

	var spark_inst = spark_effect.instantiate()
	get_parent().add_child(spark_inst)
	spark_inst.global_position = pos

	if normal:
		if normal.is_equal_approx(Vector3.DOWN):
			spark_inst.rotation_degrees.x = -90
		elif normal.is_equal_approx(Vector3.UP):
			spark_inst.rotation_degrees.x = 90
		else:
			spark_inst.look_at(pos + normal, Vector3.UP)
