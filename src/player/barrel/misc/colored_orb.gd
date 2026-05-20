extends Node3D
class_name ColoredOrb
# This orb mostly for visual feedback. Itself dont really do anything

signal finished

enum OrbState {
	FLY_RANDOM,
	PAUSE,
	HOMING
}

@export var homing_speed: float = 30
@export var random_flight_speed: float = 5
@export var random_flight_duration: float = 0.3
@export var pause_duration: float = 0.1
@export var orb_consume_sfx: AudioStream

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var trail: Trail3D = $Trail/Trail3D
@onready var light: OmniLight3D = $OmniLight3D
@onready var timer: Timer = $Lifetimer

const MIN_DIST_TO_REACH_TARGET = 1

var homing_target: Node3D = null
var velocity: Vector3
var _state: OrbState = OrbState.FLY_RANDOM
var _state_timer: float = 0.0
var _random_direction: Vector3


func _physics_process(delta: float) -> void:
	if self.process_mode == Node.PROCESS_MODE_DISABLED:
		return
		
	_state_timer += delta
	
	match _state:
		OrbState.FLY_RANDOM:
			if _state_timer >= random_flight_duration:
				_transition_to(OrbState.PAUSE)
				return
			
			# Fly in the random direction
			velocity = _random_direction * random_flight_speed * delta
			global_position += velocity
		
		OrbState.PAUSE:
			if _state_timer >= pause_duration:
				_transition_to(OrbState.HOMING)
				return
			# No movement during pause
			velocity = Vector3.ZERO
		
		OrbState.HOMING:
			if homing_target:
				var target_pos = homing_target.global_position
				if homing_target.has_node("BodyCenter"):
					target_pos = homing_target.get_node("BodyCenter").global_position
				var dir_to_target = global_position.direction_to(target_pos)
				look_at(global_position + dir_to_target)
				
				velocity = - transform.basis.z * homing_speed * delta
				global_position += velocity
				
				if global_position.distance_to(target_pos) <= MIN_DIST_TO_REACH_TARGET:
					SoundManager.play_sound_with_pitch(orb_consume_sfx, randf_range(0.8, 1.2), "SFX")
					queue_free()


func _transition_to(new_state: OrbState) -> void:
	_state = new_state
	_state_timer = 0.0
	
	match _state:
		OrbState.HOMING:
			# Face toward the target when homing starts
			if homing_target:
				var target_pos = homing_target.global_position
				if homing_target.has_node("BodyCenter"):
					target_pos = homing_target.get_node("BodyCenter").global_position
				var dir_to_target = global_position.direction_to(target_pos)
				look_at(global_position + dir_to_target)


func set_orb_color(color: Color) -> void:
	mesh.mesh.material.albedo_color = color
	trail.material_override.albedo_color = color
	trail.material_override.emission = color
	light.light_color = color


func _on_lifetimer_timeout() -> void:
	deactivate()


func activate() -> void:
	self.process_mode == Node.PROCESS_MODE_INHERIT
	self.visible = true
	# Pick a random direction for the initial flight
	_random_direction = Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-0.5, 1.0),
		randf_range(-1.0, 1.0)
	).normalized()
	
	# Face the random direction
	look_at(global_position + _random_direction)
	timer.start()


func deactivate() -> void:
	timer.stop()
	self.visible = false
	self.process_mode == Node.PROCESS_MODE_DISABLED
