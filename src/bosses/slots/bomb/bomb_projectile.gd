extends RigidBody3D
class_name BombProjectile

# This is Boss Slot's Cherry Bomb script

signal destroyed
signal split_requested(pos: Vector3)

@export_group("Bomb Behaviour")
@export var fuse_time: float = 1.0
@export var fuse_variance: float = 1.4
@export var explosion_radius: float = 8.0
@export var explosion_damage: float = 10.0
@export var landing_horizontal_damp: float = 0.2
# When player shot the cherry bomb, it reflected back to the boss
@export_group("Reflect")
@export var reflect_speed: float = 35.0
@export var reflect_fuse_time: float = 2.0
@export var reflect_color: Color = Color(1.0, 0.8, 0.1)
@export_group("SFX")
@export var sfx_bomb_launch: Array[AudioStream]
@export var sfx_bomb_bounce: Array[AudioStream]
@export var sfx_bomb_explode: Array[AudioStream]
@export_group("VFX Scenes")
@export var explosion_prefab: PackedScene
@export var spark_scene: PackedScene

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var timer: Timer = $Timer
@onready var lifetime_timer: Timer = $LifetimeTimer
@onready var explosion_area: Area3D = $ExplosionArea
@onready var explosion_collider: CollisionShape3D = $ExplosionArea/CollisionShape3D
@onready var sfx_player: AudioStreamPlayer3D = $SFXPlayer
@onready var explosion_range_indicator: MeshInstance3D = $ExplosionRangeIndicator
@onready var burn_vfx: GPUParticleController = $ProjectileBurnEmit
@onready var health_component: HealthComponent = $HealthComponent

const TREMOR_INTENSITY = 0.5
const BASE_ALBEDO_RED = 0.298
const BASE_MESH_SCALE = 4.0

var body_state: PhysicsDirectBodyState3D
var mesh_material: StandardMaterial3D
var fuse_tween: Tween
var is_active: bool = false
var is_reflected: bool = false
var has_landed: bool = false
var reflect_target: Node3D
var reflect_damage: float = 0.0
var base_explosion_radius: float
var can_split: bool = false


func _ready() -> void:
	mesh_material = mesh.mesh.surface_get_material(0).duplicate()
	mesh.set_surface_override_material(0, mesh_material)
	# Bomb shape is shared across instances, but mini bombs need their own radius
	explosion_collider.shape = explosion_collider.shape.duplicate()
	base_explosion_radius = explosion_radius
	health_component.died.connect(_on_shot)


func init(
	_damage: float,
	_fuse_time: float,
	_reflect_target: Node3D = null,
	_reflect_damage: float = 0.0,
	_size_mult: float = 1.0,
):
	activate()

	explosion_radius = base_explosion_radius * _size_mult
	mesh.scale = Vector3.ONE * BASE_MESH_SCALE * _size_mult
	explosion_damage = _damage
	explosion_collider.shape.radius = explosion_radius
	reflect_target = _reflect_target
	reflect_damage = _reflect_damage

	explosion_range_indicator.scale = Vector3.ONE * explosion_radius

	fuse_time = _fuse_time
	fuse_time += randf_range(0, fuse_variance * _size_mult)
	timer.start(fuse_time)

	mesh_material.albedo_color = Color(BASE_ALBEDO_RED, 0.305, 0.29)
	mesh_material.emission = Color.BLACK
	fuse_tween = get_tree().create_tween()
	fuse_tween.tween_property(mesh_material, "albedo_color:r", 1.0, fuse_time)


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
	if not is_active:
		return
	is_active = false
	timer.stop()

	if explode:
		explosion_collider.set_deferred("disabled", false)
		explosion_area.set_deferred("monitoring", true)
		# TODO - move to pools
		var explosion_vfx = explosion_prefab.instantiate()
		get_tree().get_root().add_child(explosion_vfx)
		explosion_vfx.global_position = self.global_position
		const EXPLOSION_VFX_SCALE_MODIFIER = 1.0
		explosion_vfx.scale_factor = explosion_radius / EXPLOSION_VFX_SCALE_MODIFIER
		explosion_vfx.explode()
		sfx_player.stream = sfx_bomb_explode.pick_random()
		sfx_player.play()
		if can_split and not is_reflected:
			split_requested.emit(global_position)

	var tween = get_tree().create_tween()

	tween.tween_property(mesh, "scale", Vector3.ZERO, 0.4).set_trans(Tween.TRANS_SINE)
	explosion_range_indicator.visible = false
	burn_vfx.deactivate()

	await tween.finished

	destroyed.emit()


func _get_reflect_target_pos() -> Vector3:
	if reflect_target.has_node("BodyCenter"):
		return reflect_target.get_node("BodyCenter").global_position
	return reflect_target.global_position


func _integrate_forces(state):
	body_state = state


func _on_shot() -> void:
	if not is_active or is_reflected or not is_instance_valid(reflect_target):
		return
	is_reflected = true

	gravity_scale = 0.0
	linear_velocity = global_position.direction_to(_get_reflect_target_pos()) * reflect_speed
	timer.start(reflect_fuse_time)

	if fuse_tween:
		fuse_tween.kill()
	mesh_material.albedo_color = reflect_color
	mesh_material.emission = reflect_color

	create_spark(global_position)
	sfx_player.stream = sfx_bomb_bounce.pick_random()
	sfx_player.play()


func _on_timer_timeout() -> void:
	destroy()


func _on_body_entered(body: Node) -> void:
	if is_reflected:
		destroy()
		return

	# Ignore brushing the boss on launch
	if not has_landed and not body is BossCore:
		has_landed = true
		linear_velocity.x *= landing_horizontal_damp
		linear_velocity.z *= landing_horizontal_damp

	var collision_pos = body_state.get_contact_local_position(0)
	var collision_normal = body_state.get_contact_local_normal(0)
	create_spark(collision_pos, collision_normal)
	sfx_player.stream = sfx_bomb_bounce.pick_random()
	sfx_player.play()


func _on_explosion_area_body_entered(body: Node3D) -> void:
	if is_reflected:
		if body is BossCore:
			body.health_component.damage(reflect_damage)
		return

	if body is Player or body is BossCore:
		body.health_component.damage(explosion_damage)
		if body is Player:
			body.player_camera.add_trauma(TREMOR_INTENSITY)


func _on_lifetime_timer_timeout() -> void:
	# Fall back in case something wrong
	deactivate()


func activate() -> void:
	is_active = true
	is_reflected = false
	has_landed = false
	can_split = false
	for other in get_collision_exceptions():
		remove_collision_exception_with(other)
	gravity_scale = 1.0
	health_component.initialize_health()
	explosion_collider.set_deferred("disabled", true)
	explosion_area.monitoring = true
	explosion_area.monitorable = true
	self.freeze = false
	self.visible = true
	explosion_range_indicator.visible = true
	self.process_mode = Node.PROCESS_MODE_INHERIT
	timer.start(fuse_time)
	lifetime_timer.start()


func deactivate() -> void:
	is_active = false
	is_reflected = false
	if fuse_tween:
		fuse_tween.kill()
	lifetime_timer.stop()
	timer.stop()
	self.freeze = true
	explosion_collider.set_deferred("disabled", true)
	explosion_area.set_deferred("monitoring", false)
	explosion_area.monitoring = false
	explosion_area.monitorable = false
	self.visible = false
	explosion_range_indicator.visible = false
	# Prevent cutoff
	if sfx_player.playing:
		await sfx_player.finished
		if is_active:
			return
	self.process_mode = Node.PROCESS_MODE_DISABLED
