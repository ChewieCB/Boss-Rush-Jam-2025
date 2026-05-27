extends Node3D
class_name SlamAOEWall

signal finished

@onready var area: Area3D = $Area3D
@onready var area_col: CollisionShape3D = $Area3D/CollisionShape3D
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var sfx_player: AudioStreamPlayer3D = $SlamWallParticles/AudioStreamPlayer3D
@onready var slam_particles: GPUParticles3D = $SlamWallParticles

@export_group("SFX")
@export var sfx_wave_loop: Array[AudioStream]
@export var sfx_flame_wall_dashed: Array[AudioStream]
@export var sfx_flame_wall_hit: Array[AudioStream]
@export var sfx_wave_impact: Array[AudioStream]

var damage: int
var max_range: float
var tween: Tween

var has_hit_player: bool = false


func init(_width: float, _height: float, _thickness: float, _damage: int, _max_range: float) -> void:
	area_col.shape.size = Vector3(_width, _height, _thickness)
	mesh.mesh.size = Vector3(_width, _height, _thickness)
	damage = _damage
	max_range = _max_range


func send_wall(
	spawned_wave_time: float = 1.0,
	area_pos: Vector3 = self.global_position,
	callback: Callable = func(): pass,
) -> void:
	if tween:
		tween.kill()
	
	_change_slam_wall_progress(0.665)
	_change_slam_wall_color(Color("#ff9e5480"))
	
	# Animate the visual
	#sfx_player.global_position = slam_particles.global_position
	#sfx_player.stream = sfx_flame_wall.pick_random()
	sfx_player.play()
	
	var forward: Vector3 = -self.global_basis.z.normalized()
	var target_pos: Vector3 = self.global_position + forward * (max_range / 2.0)
	var end_pos: Vector3 = self.global_position + forward * max_range
	# Tween animation
	tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", target_pos, spawned_wave_time)
	tween.tween_property(slam_particles, "global_position", end_pos, spawned_wave_time)
	tween.tween_callback(_end_wall).set_delay(spawned_wave_time)
	tween.tween_callback(callback).set_delay(spawned_wave_time)


func _end_wall() -> void:
	if tween:
		tween.kill()
		
	sfx_player.stop()
	
	# Dissolve animation
	tween = get_tree().create_tween()
	tween.set_parallel(false)
	tween.tween_method(
		_change_slam_wall_progress,
		0.665,
		1.0,
		0.4
	)
	tween.tween_method(
		_change_slam_wall_color,
		Color("#ff9e5480"),
		Color("#ff9e5400"),
		0.2
	)
	
	await tween.finished
	
	deactivate()
	finished.emit()


func activate() -> void:
	self.process_mode = Node.PROCESS_MODE_INHERIT
	set_physics_process(true)
	
	has_hit_player = false
	
	area.collision_layer = pow(2, 7)
	area.collision_mask = pow(2, 2 - 1) + pow(2, 7 - 1)  # Player & Cover
	area.set_deferred("monitoring", true)
	area.set_deferred("monitorable", true)
	area_col.set_deferred("disabled", false)
	
	slam_particles.emitting = true
	slam_particles.is_on_floor = true
	self.visible = true


func deactivate() -> void:
	self.visible = false
	slam_particles.emitting = false
	slam_particles.is_on_floor = false
	
	if tween:
		if tween.is_running():
			tween.kill()
	
	area.collision_layer = 0
	area.collision_mask = 0
	area.set_deferred("monitoring", false)
	area.set_deferred("monitorable", false)
	area_col.set_deferred("disabled", true)
	
	self.process_mode = Node.PROCESS_MODE_DISABLED
	set_physics_process(false)


func trigger_pushback(
	body: Node3D,
	force: float,
	pushback_source: Node3D = self,
	pushback_radius: float = area_col.shape.radius
) -> void:
	if body.global_position.distance_to(pushback_source.global_position) <= pushback_radius:
		var pushback_vector = pushback_source.global_position.direction_to(body.global_position)
		body.velocity = Vector3.ZERO
		body.vel_horizontal += Vector2(pushback_vector.x, pushback_vector.z) * force
		body.vel_vertical += 8.0


func _on_area_3d_body_entered(body: Node3D) -> void:
	_on_wave_collision(body, damage, max_range)

func _on_wave_collision(
	body: Node3D,
	aoe_damage: float,
	pushback_radius: float = area_col.shape.radius
) -> void:
		if body is Player:
			if body.is_dashing:
				SoundManager.play_sound(sfx_flame_wall_dashed.pick_random(), "SFX")
				InputHelper.rumble_small()
				_end_wall()
				return
			else:
				SoundManager.play_sound(sfx_flame_wall_hit.pick_random(), "SFX")
				InputHelper.rumble_medium()
				body.health_component.damage(aoe_damage)
				trigger_pushback(body, 10.0, self, pushback_radius)
				_end_wall()
				return
		
		SoundManager.play_sound(sfx_wave_impact.pick_random(), "SFX")


func _change_slam_wall_progress(progress: float) -> void:
	var mat: ShaderMaterial = mesh.get_active_material(0)
	mat.set_shader_parameter("rise_progress", progress)


func _change_slam_wall_color(color: Color) -> void:
	var mat: ShaderMaterial = mesh.get_active_material(0)
	mat.set_shader_parameter("color", color)
	mat.set_shader_parameter("color_edge", color)
