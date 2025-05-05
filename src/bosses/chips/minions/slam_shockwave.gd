extends Area3D

@export var max_radius: float = 20.0
@export var wave_time: float = 1.8
@export var arc_angle: float = 40.0
@export var damage: float = 10.0

@export var arc_thickness_ratio: float = 0.8
@export var arc_angle_deg := 90.0

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var collider: CollisionShape3D = $CollisionShape3D

var current_radius: float = 0.0


func start_shockwave() -> void:
	mesh.mesh.inner_radius = 0.0
	mesh.mesh.outer_radius = 0.0
	collider.shape.radius = 0.0
	var mesh_material := mesh.mesh.surface_get_material(0)
	mesh_material.set_shader_parameter("arc_start_deg", 0)
	mesh_material.set_shader_parameter("arc_end_deg", arc_angle)
	mesh.rotation_degrees.y = 90 + arc_angle/2
	collider.rotation_degrees.y = 90 + arc_angle/2
	var tween: Tween = create_tween()
	tween.tween_property(mesh.mesh, "inner_radius", max_radius * arc_thickness_ratio, wave_time)
	tween.parallel().tween_property(mesh.mesh, "outer_radius", max_radius, wave_time)
	tween.parallel().tween_property(collider.shape, "radius", max_radius, wave_time)
	#tween.parallel().tween_property(collider.shape)
	
	await tween.finished
	
	self.queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		# Flattened direction from center to player in XZ
		var to_body = (body.global_position - self.global_position)
		to_body.y = 0.0
		to_body = to_body.normalized()

		# Get forward directison of this node in XZ
		var forward = -mesh.transform.basis.z
		forward.y = 0.0
		forward = forward.normalized()

		# Get signed angle between forward and target direction in degrees
		var angle_to_body = rad_to_deg(forward.angle_to(to_body))

		# Signed direction (left or right)
		var cross = forward.cross(to_body).y
		if cross < 0:
			angle_to_body = -angle_to_body  # Make it signed (-180 to 180)
		
		angle_to_body -= 90

		var arc_half = arc_angle / 2.0  # arc_angle = total sweep, like 90°

		if angle_to_body < -arc_half or angle_to_body > arc_half:
			return  # Outside visible arc
	
		body.health_component.damage(damage)
