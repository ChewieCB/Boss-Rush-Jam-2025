extends Area3D

signal finished

@onready var timer: Timer = $Timer
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var col: CollisionShape3D = $CollisionShape3D

@export var projectile_damage: float = 10.0
@export var projectile_speed: float = 50.0


func init(_damage: float):
	projectile_damage = _damage


func activate() -> void:
	col.set_deferred("disabled", false)
	self.visible = true
	set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)


func deactivate() -> void:
	col.set_deferred("disabled", true)
	self.visible = false
	set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)


func _physics_process(delta: float) -> void:
	self.global_position -= transform.basis.z * projectile_speed * delta
	mesh.rotation += Vector3(delta, delta, delta)


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		if body is Player:
			body.health_component.damage(projectile_damage)
		finished.emit()


func _on_timer_timeout() -> void:
	finished.emit()
