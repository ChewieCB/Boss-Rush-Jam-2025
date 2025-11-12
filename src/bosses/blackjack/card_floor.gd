extends Node3D

@export var mesh: MeshInstance3D
@export var decal: Decal
@onready var material: StandardMaterial3D = mesh.mesh.surface_get_material(0)

@export var particles: GPUParticles3D
@export var fire_damage: float = 5.0

@onready var timer: Timer = $Timer
@export var lifetime: float = 5.0


func _ready() -> void:
	timer.wait_time = lifetime
	timer.start()


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is Player:
		body.health_component.damage(fire_damage)
		# TODO - add burning effect
		#body.add_status_effect()


func _on_timer_timeout() -> void:
	particles.speed_scale = 2.0
	particles.emitting = false
	var tween = get_tree().create_tween()
	tween.tween_property(mesh, "scale", Vector3.ZERO, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(decal, "scale", Vector3.ZERO, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	#tween.tween_property(material, "albedo_color:a", 0.0, 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	queue_free()
