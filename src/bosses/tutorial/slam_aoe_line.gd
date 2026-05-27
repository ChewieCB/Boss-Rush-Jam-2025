extends Node3D
class_name SlamAOELine

signal finished

@onready var area: Area3D = $Area3D
@onready var area_col: CollisionShape3D = $Area3D/CollisionShape3D
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var sfx_player: AudioStreamPlayer3D = $SlamParticles/AudioStreamPlayer3D
@onready var slam_particles: GPUParticles3D = $SlamParticles

@export_group("SFX")
@export var sfx_wave_loop: Array[AudioStream]
@export var sfx_flame_wall_dashed: Array[AudioStream]
@export var sfx_flame_wall_hit: Array[AudioStream]
@export var sfx_wave_impact: Array[AudioStream]

var damage: int
var max_range: float
var tween: Tween

var has_hit_player: bool = false


func init(_width: float, _height: float, _damage: int, _max_range: float) -> void:
	area_col.shape.size = Vector3(_width, _height, 0.1)
	mesh.mesh.size = Vector3(_width, _height, 0.05)
	damage = _damage
	max_range = _max_range


func send_line(
	spawned_wave_time: float = 1.0,
	area_pos: Vector3 = self.global_position,
	callback: Callable = func(): pass,
) -> void:
	# SFX
	sfx_player.stream = sfx_wave_loop.pick_random()
	sfx_player.play()
	
	var forward: Vector3 = -self.global_basis.z.normalized()
	var target_pos: Vector3 = self.global_position + forward * (max_range / 2.0)
	var end_pos: Vector3 = self.global_position + forward * max_range
	# Animate the visual
	tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(mesh.mesh, "size:z", max_range, spawned_wave_time)
	tween.tween_property(self, "global_position", target_pos, spawned_wave_time)
	tween.tween_property(area_col, "shape:size:z", max_range, spawned_wave_time)
	tween.tween_property(slam_particles, "global_position", end_pos, spawned_wave_time)
	#tween.tween_property(sfx_player, "global_position", end_pos, spawned_wave_time)
	tween.tween_callback(_end_line).set_delay(spawned_wave_time)
	tween.tween_callback(callback)


func _end_line() -> void:
	# TODO - fade out mesh material
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
	self.visible = true


func deactivate() -> void:
	self.visible = false
	slam_particles.emitting = false
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
			if has_hit_player:
				return
			has_hit_player = true
			if body.is_dashing:
				SoundManager.play_sound(sfx_flame_wall_dashed.pick_random(), "SFX")
				InputHelper.rumble_small()
				# Disable collision to prevent double-hits
				return
			else:
				SoundManager.play_sound(sfx_flame_wall_hit.pick_random(), "SFX")
				InputHelper.rumble_medium()
				body.health_component.damage(aoe_damage)
				trigger_pushback(body, 10.0, self, pushback_radius)
				return
		
		SoundManager.play_sound(sfx_wave_impact.pick_random(), "SFX")
