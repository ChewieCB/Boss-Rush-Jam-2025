extends CharacterBody3D

@export var navigation_component: NavigationComponent

@onready var debug_mesh: MeshInstance3D = $DebugMesh
@onready var state_chart: StateChart = $StateChart

const MAX_SPEED: float = 5.0
const TURN_SPEED: float = 7.5
const MAX_FALL_SPEED: float = 50.0
const ACCEL_RATE: float = 40.0
const JUMP_FORCE: float = 8
const GRAVITY: float = 14

var vel_vertical: float = 0


@export var target: Node3D:
	set(value):
		target = value
		if not target.is_node_ready():
			await target.ready
		navigation_component.target = target


func _ready() -> void:
	pass
	#debug_mesh.visible = false


func _physics_process(delta: float) -> void:
	if target:
		var direction: Vector3 = self.global_position.direction_to(target.global_position)
		self.rotation.y = lerp_angle(
			self.rotation.y,atan2(
				-direction.x, -direction.z
			),
			delta * TURN_SPEED
		)
		print(self.global_position.distance_to(target.global_position))
	
	vel_vertical -= GRAVITY * delta
	vel_vertical = clamp(vel_vertical, -MAX_FALL_SPEED, 10000)
	velocity.y = vel_vertical
	
	move_and_slide()


func _on_movement_idle_state_entered() -> void:
	navigation_component.disable()


func _on_movement_idle_state_physics_processing(delta: float) -> void:
	if velocity.x > 0.0:
		velocity.x = lerp(velocity.x, 0.0, delta)
	if velocity.z > 0.0:
		velocity.z = lerp(velocity.z, 0.0, delta)
	
	if target:
		if self.global_position.distance_to(target.global_position) <= 15:
			state_chart.send_event("start_moving")


func _on_movement_walking_state_entered() -> void:
	navigation_component.enable()


func _on_movement_walking_state_physics_processing(delta: float) -> void:
	if target:
		if self.global_position.distance_to(target.global_position) > 10:
			state_chart.send_event("stop_moving")
	pass
	#if target:
		#var rot_to_target: float = self.global_position.angle_to(target.global_position)
		#self.rotation = lerp(self.rotation, rot_to_target, delta * 10)
