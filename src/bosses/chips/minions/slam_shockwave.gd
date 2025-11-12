extends Area3D

signal finished

@export var max_radius: float = 20.0
@export var wave_time: float = 1.8
@export var arc_angle: float = 40.0
@export var damage: float = 10.0

@export var arc_thickness_ratio: float = 0.8
@export var arc_angle_deg := 90.0
@export var free_on_finished: bool = true

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var collider: CollisionShape3D = $CollisionShape3D
@onready var mesh_material := mesh.mesh.surface_get_material(0)

var current_radius: float = 0.0


func _ready() -> void:
	self.visible = false


func start_shockwave(wipe_arc: bool = false) -> void:
	self.visible = true
	mesh.mesh.inner_radius = 0.0
	mesh.mesh.outer_radius = 0.1
	collider.shape.radius = 0.0
	mesh_material.set_shader_parameter("arc_start_deg", 0)
	mesh_material.set_shader_parameter("arc_end_deg", arc_angle)
	#mesh.rotation_degrees.y = 90 + arc_angle/2
	var tween: Tween = create_tween()
	tween.tween_property(mesh.mesh, "inner_radius", max_radius * arc_thickness_ratio, wave_time)
	tween.parallel().tween_property(mesh.mesh, "outer_radius", max_radius, wave_time)
	tween.parallel().tween_property(collider.shape, "radius", max_radius, wave_time)
	if wipe_arc:
		pass
		#tween.parallel().tween_method(_set_arc_angle, 0.1, arc_angle, wave_time)
		
	#tween.parallel().tween_property(collider.shape)
	
	await tween.finished
	
	self.visible = false
	mesh.mesh.inner_radius = 0.0
	mesh.mesh.outer_radius = 0.1
	collider.shape.radius = 0.0
	mesh_material.set_shader_parameter("arc_start_deg", 0)
	mesh_material.set_shader_parameter("arc_end_deg", arc_angle)
	
	finished.emit()
	
	if free_on_finished:
		self.queue_free()


func _set_arc_angle(angle: float) -> void:
	mesh_material.set_shader_parameter("arc_end_deg", angle)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		# Check player hasn't jumped over the arc
		if self.global_position.distance_to(body.global_position) > collider.shape.radius * arc_thickness_ratio:
			# Check player is in view of arc
			var arc_facing_dir: Vector3 = -self.global_transform.basis.z.normalized()
			var to_body_dir: Vector3 = self.global_position.direction_to(body.global_position).normalized()
			
			var angle_threshold: float = cos(deg_to_rad(arc_angle / 2))
			var dot_product: float = arc_facing_dir.dot(to_body_dir)
			
			if dot_product > angle_threshold:
				body.health_component.damage(damage)
