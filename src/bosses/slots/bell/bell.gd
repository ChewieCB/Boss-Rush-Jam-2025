extends CharacterBody3D
class_name Bell

signal destroyed(bell: Bell)

@export var fall_speed: float = 50.0
@export var damage: float = 20.0
var floor_y: float

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var collider: CollisionShape3D = $CollisionShape3D
@onready var hurtbox: Area3D = $Hurtbox
@onready var hurtbox_collider: CollisionShape3D = $Hurtbox/CollisionShape3D

#@export var health_component: HealthComponent
@export var explosion_scene: PackedScene
@export var spark_scene: PackedScene


func _ready() -> void:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		self.global_position, 
		self.global_position - Vector3(0, 100, 0),
		pow(2, 1-1) + pow(2, 7-1)
	)
	var result = space_state.intersect_ray(query)
	if result:
		floor_y = result.position.y
	
	var tween = get_tree().create_tween()
	tween.tween_property(mesh.mesh.surface_get_material(0), "albedo_color:a", 255, 0.3).set_trans(Tween.TRANS_EXPO)
	
	for i in range(3):
		var pos = self.global_position - self.global_basis.z.rotated(
			Vector3.UP, 
			2 * PI / i+1
		) * 4.0
		spark(pos)


func _physics_process(delta: float) -> void:
	if self.global_position.y <= floor_y:
		destroy()
	else:
		global_position.y -= fall_speed * delta
	


func spark(spark_pos: Vector3) -> void:
	var spark_vfx = spark_scene.instantiate()
	get_tree().get_root().add_child(spark_vfx)
	spark_vfx.global_position = spark_pos


func destroy() -> void:
	for i in range(4):
		var pos = self.global_position + Vector3(0, 2.0, 0) - self.global_basis.z.rotated(
			Vector3.UP, 
			2 * PI / i+1
		) * collider.shape.radius
		var explosion_vfx = explosion_scene.instantiate()
		get_tree().get_root().add_child(explosion_vfx)
		explosion_vfx.original_fire_size = Vector2(10, 10)
		explosion_vfx.original_smoke_size = Vector2(6, 6)
		explosion_vfx.global_position = pos
		await get_tree().create_timer(0.05).timeout
	
	var tween = get_tree().create_tween()
	tween.tween_property(mesh.mesh.surface_get_material(0), "albedo_color:a", 0, 0.14).set_trans(Tween.TRANS_EXPO)
	tween.tween_callback(destroyed.emit.bind(self))
	tween.tween_callback(self.queue_free)


func _on_hurtbox_body_entered(body: Node3D) -> void:
	if body is Player:
			body.health_component.damage(damage)
		# TODO - damage boss? Allow kiting?
