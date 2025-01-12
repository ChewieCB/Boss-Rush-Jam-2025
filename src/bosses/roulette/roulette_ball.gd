extends RigidBody3D
class_name RouletteBall

signal destroyed(ball: RouletteBall)

var body_state: PhysicsDirectBodyState3D
@export var max_collisions: int = 15
var collision_count: int = 0

@export var damage: float = 15
@export var wheel_center: Vector3 = Vector3.ZERO
@export var target: Node3D
@export var homing_delay: float = 2.5
@export var radial_force_magnitude: float = 1600
@export var central_force_magnitude: float = 3800
@export var homing_force_magnitude: float = 5000

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var material: StandardMaterial3D = mesh.mesh.material
@onready var homing_timer: Timer = $Timer


func _ready() -> void:
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
		var homing_force = self.global_position.direction_to(target.global_position) * homing_force_magnitude
		apply_central_force(homing_force)
		apply_central_force(central_force)
	
	else:
		apply_central_force(central_force / 2)


func destroy() -> void:
	destroyed.emit(self)
	queue_free()


func _integrate_forces(state):
	body_state = state


func _on_body_entered(body: Node) -> void:
	if body == target:
		material.albedo_color = Color.RED
		target.health_component.damage(damage)
		destroy()
	else:
		# Only increment environment collisions if the normal of the collision is not vertical
		var collision_normal = body_state.get_contact_local_normal(0)
		if collision_normal == Vector3.UP:
			pass
		else:
			collision_count += 1
			material.albedo_color = Color.RED
			if collision_count == max_collisions:
				destroy()
			await get_tree().create_timer(0.1).timeout
			material.albedo_color = Color.WHITE
			
