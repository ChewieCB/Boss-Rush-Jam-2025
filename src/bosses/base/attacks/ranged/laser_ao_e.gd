extends Area3D
class_name LaserAoE

@export var damage: float = 40.0
@export var fade_time: float = 1.4

@onready var mesh := $MeshInstance3D


func _ready() -> void:
	var mat: StandardMaterial3D = mesh.get_active_material(0).duplicate()
	mat.albedo_color.a = 0.557
	mesh.set_surface_override_material(0, mat)
	
	await get_tree().physics_frame
	await get_tree().physics_frame
	set_deferred("monitoring", false)
	
	var laser_tween := get_tree().create_tween()
	laser_tween.tween_property(
		mat, 
		"albedo_color:a",
		0.0,
		2.0
	)
	await laser_tween.finished
	self.queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		body.health_component.damage(damage)
