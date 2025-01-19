extends RigidBody3D
class_name RouletteBall

signal destroyed(ball: RouletteBall)

var body_state: PhysicsDirectBodyState3D
@export var max_collisions: int = -1
var collision_count: int = 0

@export var damage: float = 15
@export var wheel_center: Vector3 = Vector3.ZERO
@export var target: Node3D
@export var homing_delay: float = 1.7
@export var radial_force_magnitude: float = 1700
@export var central_force_magnitude: float = 3800
@export var homing_force_magnitude: float = 5550
@export var is_flaming: bool = false:
	set(value):
		is_flaming = value
		fire_mesh.visible = is_flaming

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var fire_mesh: MeshInstance3D = $FireMesh
@onready var material: StandardMaterial3D = mesh.mesh.material
@onready var homing_timer: Timer = $Timer

@export var health_component: HealthComponent
@export var explosion_scene: PackedScene
@export var spark_scene: PackedScene


func _ready() -> void:
	health_component.died.connect(destroy)
	homing_timer.wait_time = homing_delay
	homing_timer.start()


func _physics_process(_delta: float) -> void:
	var to_sphere = self.global_transform.origin - wheel_center
	var tangent_dir = Vector3.UP.cross(to_sphere).normalized()
	var ball_force = tangent_dir * radial_force_magnitude
	var central_force = self.global_position.direction_to(wheel_center) * central_force_magnitude
	# Close circle = 1500 | 10,000
	# Mid circle = ? | ?
	apply_central_force(ball_force)
	
	if target and homing_timer.is_stopped():
		if not is_instance_valid(target):
			return
		var homing_force = self.global_position.direction_to(target.global_position) * homing_force_magnitude
		apply_central_force(homing_force)
		apply_central_force(central_force)
	else:
		apply_central_force(central_force)


func spark(spark_pos: Vector3) -> void:
	var spark_vfx = spark_scene.instantiate()
	get_tree().get_root().add_child(spark_vfx)
	spark_vfx.global_position = spark_pos


func destroy() -> void:
	sleeping = true
	call_deferred("set_contact_monitor", false)
	
	var explosion_vfx = explosion_scene.instantiate()
	get_tree().get_root().add_child(explosion_vfx)
	explosion_vfx.global_position = self.global_position
	
	var tween = get_tree().create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.4).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(destroyed.emit.bind(self))
	tween.tween_callback(self.queue_free)


func _integrate_forces(state):
	body_state = state


func _on_body_entered(body: Node) -> void:
	if body == target:
		target.health_component.damage(damage)
		destroy()
	if body is BaseProjectile:
		pass
	else:
		# Only increment environment collisions if the normal of the collision is not vertical
		var collision_normal = body_state.get_contact_local_normal(0)
		if collision_normal == Vector3.UP:
			pass
		else:
			var spark_pos: Vector3 = body_state.get_contact_collider_position(0)
			spark(spark_pos)
			
			collision_count += 1
			if collision_count == max_collisions and max_collisions > 0:
				destroy()
