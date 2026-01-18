extends RigidBody3D
class_name BombProjectile

@export_group("Bomb Behaviour")
@export var fuse_time: float = 1.0
@export var fuse_variance: float = 1.4
@export var explosion_radius: float = 8.0
@export var explosion_damage: float = 10.0
@export_group("SFX")
@export var sfx_bomb_launch: Array[AudioStream]
@export var sfx_bomb_bounce: Array[AudioStream]
@export var sfx_bomb_explode: Array[AudioStream]
@export_group("VFX Scenes")
@export var explosion_prefab: PackedScene
@export var spark_scene: PackedScene

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var timer: Timer = $Timer
@onready var explosion_area: Area3D = $ExplosionArea
@onready var explosion_collider: CollisionShape3D = $ExplosionArea/CollisionShape3D
@onready var sfx_player: AudioStreamPlayer3D = $SFXPlayer
@onready var explosion_range_indicator: MeshInstance3D = $ExplosionRangeIndicator
@onready var burn_vfx: GPUParticleController = $ProjectileBurnEmit

const TREMOR_INTENSITY = 0.5

var body_state: PhysicsDirectBodyState3D


func _ready() -> void:
	explosion_collider.shape.radius = explosion_radius
	timer.start(fuse_time)
	var tween = get_tree().create_tween()
	explosion_range_indicator.scale = Vector3.ONE * explosion_radius
	tween.tween_property(mesh.mesh.surface_get_material(0), "albedo_color:r", 1.0, fuse_time)

func init(_damage: float, _fuse_time: float):
	explosion_damage = _damage
	fuse_time = _fuse_time
	fuse_time += randf_range(0, fuse_variance)

func create_spark(pos: Vector3, normal: Vector3 = Vector3.ZERO):
	var spark_inst = spark_scene.instantiate()
	get_parent().add_child(spark_inst)
	spark_inst.global_position = pos

	if normal:
		if normal.is_equal_approx(Vector3.DOWN):
			spark_inst.rotation_degrees.x = -90
		elif normal.is_equal_approx(Vector3.UP):
			spark_inst.rotation_degrees.x = 90
		else:
			spark_inst.look_at(pos + normal, Vector3.UP)


func destroy(explode: bool = true) -> void:
	if explode:
		explosion_area.set_deferred("monitoring", true)
		var explosion_vfx = explosion_prefab.instantiate()
		get_tree().get_root().add_child(explosion_vfx)
		explosion_vfx.global_position = self.global_position
		const EXPLOSION_VFX_SCALE_MODIFIER = 1.0
		explosion_vfx.scale_factor = explosion_radius / EXPLOSION_VFX_SCALE_MODIFIER
		explosion_vfx.explode()
		sfx_player.stream = sfx_bomb_explode.pick_random()
		sfx_player.play()
	var tween = get_tree().create_tween()

	# Hide the bomb
	tween.tween_property(mesh, "scale", Vector3.ZERO, 0.4).set_trans(Tween.TRANS_SINE)
	explosion_range_indicator.visible = false
	burn_vfx.deactivate()
	freeze = true
	
	# Wait for effect finished
	if sfx_player.playing:
		await sfx_player.finished
	else:
		await tween.finished
	queue_free() 

func _integrate_forces(state):
	body_state = state


func _on_timer_timeout() -> void:
	destroy()


func _on_body_entered(_body: Node) -> void:
	var collision_pos = body_state.get_contact_local_position(0)
	var collision_normal = body_state.get_contact_local_normal(0)
	create_spark(collision_pos, collision_normal)
	sfx_player.stream = sfx_bomb_bounce.pick_random()
	sfx_player.play()


func _on_explosion_area_body_entered(body: Node3D) -> void:
	if body is Player or body is BossCore:
		body.health_component.damage(explosion_damage)
		if body is Player:
			body.player_camera.add_trauma(TREMOR_INTENSITY)

func _on_lifetime_timer_timeout() -> void:
	# Fall back in case something wrong
	queue_free()
