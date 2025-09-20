extends StaticBody3D
class_name Bell

signal destroyed(bell: Bell)

@export var damage: float = 20.0
var floor_y: float = 0.0

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var collider: CollisionShape3D = $CollisionShape3D
@onready var hurtbox: Area3D = $Hurtbox
@onready var hurtbox_collider: CollisionShape3D = $Hurtbox/CollisionShape3D

@export var explosion_scene: PackedScene
@export var spark_scene: PackedScene

@onready var sfx_player: AudioStreamPlayer3D = $SFXPlayer
@export_group("SFX")
@export var sfx_bell_full: Array[AudioStream]
@export var sfx_bell_windup: Array[AudioStream]
@export var sfx_bell_impact: Array[AudioStream]


func init(_damage: float):
	damage = _damage

func drop() -> void:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		self.global_position,
		self.global_position - Vector3(0, 100, 0),
		int(pow(2, 1 - 1) + pow(2, 7 - 1))
	)
	var result = space_state.intersect_ray(query)
	if result:
		floor_y = result.position.y
	
	mesh.visible = true
	mesh.mesh.surface_get_material(0).albedo_color = Color("#b08137")
	#tween.tween_property(mesh.mesh.surface_get_material(0), "albedo_color:a", 255, 0.3).set_trans(Tween.TRANS_EXPO)
	
	for i in range(3):
		var pos = self.global_position - self.global_basis.z.rotated(
			Vector3.UP,
			2 * PI / i + 1
		) * 4.0
		spark(pos)
	
	sfx_player.stream = sfx_bell_full.pick_random()
	sfx_player.play()
	var tween: Tween = get_tree().create_tween()
	# 1.04s is the timestamp of the impact in the full bell sfx samples
	tween.tween_property(self, "global_position:y", floor_y, 1.04)
	tween.tween_callback(destroy)


func spark(spark_pos: Vector3) -> void:
	var spark_vfx = spark_scene.instantiate()
	get_tree().get_root().add_child(spark_vfx)
	spark_vfx.global_position = spark_pos


func destroy() -> void:
	sfx_player.stream = sfx_bell_impact.pick_random()
	sfx_player.play()

	for i in range(4):
		var pos = self.global_position + Vector3(0, 2.0, 0) - self.global_basis.z.rotated(
			Vector3.UP,
			2 * PI / i + 1
		) * collider.shape.radius
		var explosion_vfx = explosion_scene.instantiate()
		get_tree().get_root().get_child(7).add_child(explosion_vfx)
		explosion_vfx.original_fire_size = Vector2(10, 10)
		explosion_vfx.original_smoke_size = Vector2(6, 6)
		explosion_vfx.global_position = pos
		await get_tree().create_timer(0.05).timeout
	
	var tween = get_tree().create_tween()
	tween.tween_property(mesh.mesh.surface_get_material(0), "albedo_color:a", 0, 0.14).set_trans(Tween.TRANS_EXPO)
	tween.tween_callback(_on_destroyed)


func _on_destroyed() -> void:
	destroyed.emit(self)
	mesh.visible = false
	hurtbox_collider.disabled = true
	collider.disabled = true
	if sfx_player.playing:
		await sfx_player.finished
	queue_free()


func _on_hurtbox_body_entered(body: Node3D) -> void:
	if body is Player:
			body.health_component.damage(damage)
		# TODO - damage boss? Allow kiting?
