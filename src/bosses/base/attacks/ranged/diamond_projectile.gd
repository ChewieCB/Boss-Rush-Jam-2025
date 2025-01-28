extends Area3D
class_name DiamondProjectile

@onready var life_timer: Timer = $LifeTimer
@onready var homing_delay_timer: Timer = $HomingDelay
@onready var homing_timer: Timer = $HomingTimer

@export var damage: float = 3.0
@export var speed: float = 35.0
@export var rotation_speed: float = 25.0
@export var target: CharacterBody3D
@export var homing_delay: float = 0.15
@export var homing_time: float = 0.3

@export var spark_effect: PackedScene

var velocity: Vector3
var rot: Vector3
var collision_count: int = 0


func _ready() -> void:
	homing_delay_timer.start(homing_delay)
	homing_timer.start(homing_time)

# TODO - rework this using the gun projectile so we can get impacts and ricochets

func _physics_process(delta: float) -> void:
	if homing_delay_timer.is_stopped() and not homing_timer.is_stopped():
		var direction = target.global_transform.origin - self.global_transform.origin
		direction = direction.normalized()
		var rotation_amount: Vector3 = direction.cross(self.global_transform.basis.z)
		rot.y = rotation_amount.y * rotation_speed * delta
		rot.x = rotation_amount.x * rotation_speed * delta
		rotate(Vector3.UP, rot.y)
		rotate(Vector3.RIGHT, rot.x)
		
		global_translate(-self.global_transform.basis.z * speed * delta)
	else:
		self.global_position -= transform.basis.z * speed * delta


func destroy() -> void:
	queue_free()


func create_spark(pos: Vector3, normal: Vector3 = Vector3.ZERO):
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


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		body.health_component.damage(damage)
	create_spark(
		self.global_position, 
		body.global_position.direction_to(self.global_position)
	)
	collision_count += 1
	if collision_count > 1:
		queue_free()


func _on_body_exited(body: Node3D) -> void:
	create_spark(
		self.global_position, 
		body.global_position.direction_to(self.global_position)
	)



func _on_life_timer_timeout() -> void:
	create_spark(self.global_position)
	destroy()


func _on_homing_delay_timeout() -> void:
	homing_timer.start(homing_delay)
