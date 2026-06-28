extends Area3D
class_name ArcProjectile

signal finished

@export var timer: Timer
@export var mesh: CSGCombiner3D
@export var col: CollisionShape3D

@export var projectile_damage: float = 10.0
@export var projectile_speed: float = 50.0
@export var rotation_speed: float = 1.0
@export var arc_height: float = 5.0
@export var GRAVITY: float = 14
@export var spark_scene: PackedScene
#var debug_trajectory_mesh: MeshInstance3D

var velocity := Vector3.ZERO


func _ready() -> void:
	#debug_trajectory_mesh = MeshInstance3D.new()
	#debug_trajectory_mesh.mesh = ImmediateMesh.new()
	#get_tree().get_root().add_child.call_deferred(debug_trajectory_mesh)
	pass


func _physics_process(delta: float) -> void:
	#self.global_position -= transform.basis.z * projectile_speed * delta
	velocity.y -= GRAVITY * delta
	self.global_position += velocity * delta
	#mesh.rotation.z += delta * rotation_speed
	mesh.rotation.x += delta * rotation_speed


func get_arc_vector(goal_pos: Vector3, debug: bool = false) -> Vector3:
	var start_pos = self.global_position
	var highest_y = max(start_pos.y, goal_pos.y)
	var apex_y = highest_y + arc_height
	
	var velocity_v: float = sqrt(
		2 * GRAVITY * (apex_y - start_pos.y) * projectile_speed
	)
	
	# TODO - make time_up and time_down configurable so we can set a jump time
	var time_up: float = velocity_v / GRAVITY
	var time_down: float = sqrt(2.0 * (apex_y - goal_pos.y) / GRAVITY)
	var time: float = time_up + time_down
	
	var displacement_xz: Vector2 = Vector2(goal_pos.x, goal_pos.z) - Vector2(start_pos.x, start_pos.z)
	var horizontal_distance: float = displacement_xz.length()
	var velocity_h = horizontal_distance / time
	var horizontal_dir: Vector2 = displacement_xz.normalized()
	
	var initial_velocity := Vector3(
		horizontal_dir.x * velocity_h,
		velocity_v,
		horizontal_dir.y * velocity_h,
	)
	
	# Drawing
	#if debug:
		#var trajectory_points: Array = []
		#
		#for i in range(1, 151):
			#var t = time * float(i) / float(151)
			#var x = start_pos.x + initial_velocity.x * t
			#var y = start_pos.y + initial_velocity.y * t - 0.5 * GRAVITY * t * t
			#var z = start_pos.z + initial_velocity.z * t
			#trajectory_points.append(Vector3(x, y, z))
		#
		#debug_trajectory_mesh.mesh.clear_surfaces()
		#debug_trajectory_mesh.mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		#for p in trajectory_points:
			#debug_trajectory_mesh.mesh.surface_set_color(Color.RED)
			#debug_trajectory_mesh.mesh.surface_add_vertex(p)
		#debug_trajectory_mesh.mesh.surface_end()
		
	return initial_velocity


func _on_body_entered(body: Node3D) -> void:
	if not monitoring or process_mode == Node.PROCESS_MODE_DISABLED:
		return
	
	spark()
	if body is Player:
		body.health_component.damage(projectile_damage)
	# TODO - make this have collision exception based on who fired it
	elif body is BossCore:
		pass
	else:
		finished.emit()


# TODO - make a global util method
func spark() -> void:
	var spark_vfx = spark_scene.instantiate()
	get_parent().get_parent().add_child(spark_vfx)
	spark_vfx.global_position = self.global_position


func _on_timer_timeout() -> void:
	finished.emit()


func activate() -> void:
	col.set_deferred("disabled", false)
	self.monitoring = true
	self.monitorable = true
	self.visible = true
	self.process_mode = Node.PROCESS_MODE_INHERIT


func deactivate() -> void:
	col.set_deferred("disabled", true)
	self.monitoring = false
	self.monitorable = false
	self.visible = false
	self.process_mode = Node.PROCESS_MODE_DISABLED
