extends RigidBody3D
class_name BombProjectile

@export var fuse_time: float = 1.0
@export var fuse_variance: float = 1.4
@export var ticks: int = 3
@export var explosion_radius: float = 8.0
@export var explosion_damage: float = 10.0

@export var explosion_scene: PackedScene
@export var spark_scene: PackedScene

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var timer: Timer = $Timer
@onready var explosion_area: Area3D = $ExplosionArea
@onready var explosion_collider: CollisionShape3D = $ExplosionArea/CollisionShape3D

var body_state: PhysicsDirectBodyState3D


func _ready() -> void:
	explosion_collider.shape.radius = explosion_radius
	fuse_time += randf_range(0, fuse_variance)
	timer.start(fuse_time)
	
	var tick_time: float = fuse_time / ticks
	var mesh_color: Color = mesh.mesh.surface_get_material(0).albedo_color
	for i in range(ticks):
		var tween = get_tree().create_tween()
		tween.tween_property(mesh.mesh.surface_get_material(0), "albedo_color:r", 255 * 0.65, tick_time / 2).set_trans(Tween.TRANS_CIRC)
		tween.chain().tween_property(mesh.mesh.surface_get_material(0), "albedo_color", mesh_color, tick_time / 2).set_trans(Tween.TRANS_EXPO)


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


func destroy() -> void:
	explosion_area.set_deferred("monitoring", true)
	var explosion_vfx = explosion_scene.instantiate()
	get_tree().get_root().add_child(explosion_vfx)
	explosion_vfx.global_position = self.global_position
	# TODO - make explosion size of area
	
	var tween = get_tree().create_tween()
	tween.tween_property(mesh, "scale", Vector3.ZERO, 0.4).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(self.queue_free)


func _integrate_forces(state):
	body_state = state


func _on_timer_timeout() -> void:
	destroy()


func _on_body_entered(body: Node) -> void:
	var collision_pos = body_state.get_contact_local_position(0)
	var collision_normal = body_state.get_contact_local_normal(0)
	create_spark(collision_pos, collision_normal)


func _on_explosion_area_body_entered(body: Node3D) -> void:
	if body is Player or body is BossCore:
		body.health_component.damage(explosion_damage)
	elif body is BombProjectile:
		body.destroy()
