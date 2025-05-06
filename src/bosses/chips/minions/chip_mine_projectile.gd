extends CharacterBody3D
class_name ChipMineProjectile

@export_group("Bomb Behaviour")
@export var fuse_time: float = 1.6
@export var fuse_variance: float = 1.4
@export var ticks: int = 3
@export var explosion_radius: float = 8.0
@export var explosion_damage: float = 10.0
@export_subgroup("Movement")
@export var acceleration: float = 8.0
@export var max_speed: float = 12.0
@export var steering_damping: float = 0.8
@export_group("SFX")
@export var sfx_bomb_launch: Array[AudioStream]
@export var sfx_bomb_bounce: Array[AudioStream]
@export var sfx_bomb_explode: Array[AudioStream]
@export_group("VFX Scenes")
@export var explosion_scene: PackedScene
@export var spark_scene: PackedScene

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var mesh_mat: Material = mesh.mesh.surface_get_material(0)
@onready var timer: Timer = $Timer
@onready var acivation_area: Area3D = $ActivationArea
@onready var explosion_area: Area3D = $ExplosionArea
@onready var explosion_collider: CollisionShape3D = $ExplosionArea/CollisionShape3D
@onready var sfx_player: AudioStreamPlayer3D = $SFXPlayer
@onready var health_component: HealthComponent = $HealthComponent

var body_state: PhysicsDirectBodyState3D

var has_detonated: bool = false

var target: CharacterBody3D
var drift_velocity := Vector3.ZERO


func _ready() -> void:
	explosion_collider.shape.radius = explosion_radius
	fuse_time += randf_range(0, fuse_variance)


func _physics_process(delta: float) -> void:
	if target:
		var to_target: Vector3 = target.global_position - self.global_position
		var desired_velocity: Vector3 = to_target.normalized() * max_speed
		
		# Smooth steering towards target
		drift_velocity = drift_velocity.lerp(desired_velocity, acceleration * delta)
		drift_velocity *= steering_damping
		
		self.velocity = drift_velocity
		move_and_slide()


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


func detonate() -> void:
	has_detonated = true
	
	mesh_mat.albedo_color = Color.RED
	mesh.scale *= 0.25
	
	explosion_area.set_deferred("monitoring", true)
	var explosion_vfx = explosion_scene.instantiate()
	get_tree().get_root().add_child(explosion_vfx)
	explosion_vfx.global_position = self.global_position
	explosion_vfx.change_mesh_scale(2)
	# TODO - make explosion size of area
	
	var test0 = explosion_area.get_overlapping_bodies()
	for body in explosion_area.get_overlapping_bodies():
		if body == self:
			continue
		_on_explosion_area_body_entered(body)
	
	#var tween = get_tree().create_tween()
	#tween.tween_property(mesh_mat, "albedo_color", Color.BLACK, 0.1).set_trans(Tween.TRANS_CIRC)
	#tween.parallel().tween_property(mesh, "scale", Vector3(0.1, 0.1, 0.1), 0.1).set_trans(Tween.TRANS_CIRC)
	
	sfx_player.stream = sfx_bomb_explode.pick_random()
	sfx_player.play()
	
	self.queue_free()


func _on_timer_timeout() -> void:
	detonate()


func _on_explosion_area_body_entered(body: Node3D) -> void:
	if body is Player or body is BossCore:
		body.health_component.damage(explosion_damage)
	elif body is ChipMineProjectile:
		if not body.has_detonated:
			body.detonate()


func _on_activation_area_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		if body is ChipMineProjectile:
			return
		target = body
		
		acivation_area.set_deferred("monitoring", false)
		timer.start(fuse_time)
		
		var anim_tick: float = fuse_time / ticks / 2
		
		var tween = get_tree().create_tween()
		tween.tween_property(mesh_mat, "albedo_color", Color.RED, anim_tick).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
		tween.chain().tween_property(mesh_mat, "albedo_color", Color.DARK_ORANGE, anim_tick).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.set_loops(ticks)


func _on_contact_area_body_entered(body: Node3D) -> void:
	if body == self or has_detonated:
		return
	if body is CharacterBody3D:
		detonate()
