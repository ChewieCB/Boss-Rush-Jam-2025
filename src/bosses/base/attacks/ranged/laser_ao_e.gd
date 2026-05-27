extends Area3D
class_name LaserAoE

signal finished

@export var damage: float = 40.0
@export var damage_active_time: float = 0.2
@export var fade_time: float = 1.4

@onready var mesh := $MeshInstance3D
@onready var col := $CollisionShape3D
var mat: StandardMaterial3D
const ALPHA_INIT: float =  0.557


func _ready() -> void:
	_make_material_unique()
	set_deferred("monitoring", false)


func _make_material_unique() -> void:
	mat = mesh.get_active_material(0).duplicate()
	mat.albedo_color.a = ALPHA_INIT
	mesh.set_surface_override_material(0, mat)


func activate() -> void:
	self.process_mode = Node.PROCESS_MODE_INHERIT
	set_physics_process(true)
	
	self.collision_layer = pow(2, 4-1)
	self.collision_mask = pow(2, 2-1)
	set_deferred("monitorable", true)
	col.set_deferred("disabled", false)
	
	self.visible = true
	mat.albedo_color.a = 1.0


func deactivate() -> void:
	self.visible = false
	
	self.collision_layer = 0
	self.collision_mask = 0
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	col.set_deferred("disabled", true)
	
	self.process_mode = Node.PROCESS_MODE_DISABLED
	set_physics_process(false)


func fire_laser() -> void:
	set_deferred("monitoring", true)
	
	#await get_tree().physics_frame
	var laser_tween := get_tree().create_tween().set_parallel(true)
	laser_tween.tween_callback(
		func():
			set_deferred("monitoring", false)
	).set_delay(damage_active_time)
	laser_tween.tween_property(
		mat,
		"albedo_color:a",
		0.0,
		2.0
	)
	await laser_tween.finished
	
	finished.emit()
	deactivate()


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		knockback(body, damage, 15.0)


func knockback(body: Node3D, knockback_damage: float, force: float) -> void:
	body.health_component.damage(knockback_damage)
	var pushback_vector = self.global_position.direction_to(body.global_position)
	
	body.velocity = Vector3.ZERO
	body.vel_horizontal += Vector2(pushback_vector.x, pushback_vector.z) * force
	body.vel_vertical += pushback_vector.y * force
