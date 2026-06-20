extends Area3D
class_name TestProjectile

signal finished

@onready var col: CollisionShape3D = $CollisionShape3D
@onready var trail: Trail3D = $Trail/Trail3D
@onready var timer: Timer = $Timer

@export var projectile_damage: float = 10.0
@export var projectile_speed: float = 50.0

# TODO - rework this using the gun projectile so we can get impacts and ricochets

func init(_damage: float):
	projectile_damage = _damage


func activate() -> void:
	self.process_mode = Node.PROCESS_MODE_INHERIT
	trail.process_mode = Node.PROCESS_MODE_INHERIT
	set_physics_process(true)
	
	self.collision_layer = pow(2, 7)
	self.collision_mask = pow(2, 2 - 1) + pow(2, 7 - 1)  # Player & Cover
	self.set_deferred("monitoring", true)
	self.set_deferred("monitorable", true)
	col.set_deferred("disabled", false)
	trail.process_mode = Node.PROCESS_MODE_INHERIT
	
	self.visible = true


func deactivate() -> void:
	self.visible = false
	
	self.collision_layer = 0
	self.collision_mask = 0
	self.set_deferred("monitoring", false)
	self.set_deferred("monitorable", false)
	col.set_deferred("disabled", true)
	
	trail.full_reset()
	trail.process_mode = Node.PROCESS_MODE_DISABLED
	self.process_mode = Node.PROCESS_MODE_DISABLED
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	self.global_position -= transform.basis.z * projectile_speed * delta
	

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		body.health_component.damage(projectile_damage)
	# TODO - make this have collision exception based on who fired it
	elif body is BossCore:
		pass
	else:
		finished.emit()
		deactivate()


func _on_timer_timeout() -> void:
	finished.emit()
	deactivate()
