extends Area3D
class_name ShakeCameraWrapper

@export_category("Shake")
@export var trauma_reduction_rate = 1.0
@export var max_x = 10.0
@export var max_y = 10.0
@export var max_z = 5.0
@export var noise: FastNoiseLite
@export var noise_speed = 50.0
@export_category("Recoil")
@export var recoil: Vector3 = Vector3(1, 0, 0)

@onready var camera: Camera3D = $Camera3D
@onready var initial_rotation: Vector3 = camera.rotation_degrees
@onready var gun_container = $GunContainer

# Statuses
@export_group("Status Effects")
@export_subgroup("Drunk")
var drunk_sway_time: float = 0.0
@export var drunk_sway_speed: float = 1.5
@export var drunk_sway_amount_deg: float = 5.0
@export var drunk_noise_intensity: float = 3.0
var drunk_intensity: float = 0.0
@export var target_drunk_intensity: float = 0.0
var sway_noise := FastNoiseLite.new()

const MAX_TRAUMA = 2.0
const SHAKE_COEFFICIENT = 1.0
const RECOIL_DAMPING_FACTOR = 10.0
const GLOBAL_RECOIL_COEFFICIENT = 20.0
const JERK_GUN_DAMPING_FACTOR = 4.0

var trauma = 0.0
var long_trauma = 0.0 # Trauma over a long duration
var time = 0.0
var current_rotation: Vector3
var target_rotation: Vector3
var rotation_velocity: Vector3
var recoil_power: float = 0
var recover_rotation_velocity: Vector3

var original_gun_container_pos: Vector3
var jerk_gun_tween: Tween

func _ready() -> void:
	original_gun_container_pos = gun_container.position

func _process(delta):
	# Trauma
	time += delta
	trauma = max(trauma - delta * trauma_reduction_rate, 0.0)
	var final_trauma = clamp(trauma + long_trauma, 0.0, MAX_TRAUMA)

	camera.rotation_degrees.x = initial_rotation.x + max_x * get_shake_intensity(final_trauma) * get_noise_from_seed(0)
	camera.rotation_degrees.y = initial_rotation.y + max_y * get_shake_intensity(final_trauma) * get_noise_from_seed(1)
	camera.rotation_degrees.z = initial_rotation.z + max_z * get_shake_intensity(final_trauma) * get_noise_from_seed(2)

	# Recoil
	rotation_velocity -= rotation_velocity * RECOIL_DAMPING_FACTOR * delta
	recover_rotation_velocity -= recover_rotation_velocity * (RECOIL_DAMPING_FACTOR / 2.0) * delta
	var final_rotation_velocity = rotation_velocity + recover_rotation_velocity
	rotation += final_rotation_velocity * delta
	
	# Drunk
	drunk_intensity = lerp(drunk_intensity, target_drunk_intensity, delta * 2.0)
	if drunk_intensity > 0.01:
		drunk_sway_time += delta * drunk_sway_speed
	
		var sway_pitch: float = sin(drunk_sway_time) * drunk_sway_amount_deg * 0.25 * drunk_intensity
		var sway_yaw: float = cos(drunk_sway_time * 1.5) * drunk_sway_amount_deg * 0.25 * drunk_intensity
		var sway_roll: float = sin(drunk_sway_time * 0.6) * drunk_sway_amount_deg * drunk_intensity
		
		# Add some procedural jitter
		var noise_offset = get_noise_from_seed(Time.get_ticks_msec() * 0.001) * drunk_noise_intensity
		
		var wobble_vector := Vector3(
			sway_pitch, #+ noise_offset,
			sway_yaw,
			sway_roll * 0.25
		)
		
		camera.rotation_degrees += wobble_vector


func add_long_trauma(trauma_amount: float):
	# Trauma over long duration, such as during sliding, earthquake, house collapsing, ...
	long_trauma = clamp(long_trauma + trauma_amount, 0.0, MAX_TRAUMA)

func add_trauma(trauma_amount: float):
	# Trauma over single tick, such as gunfire, small explosion, attacked, ...
	trauma = clamp(trauma_amount, 0.0, MAX_TRAUMA) # Yes it replace existing trauma

func get_shake_intensity(_trauma: float) -> float:
	return _trauma * SHAKE_COEFFICIENT

func get_noise_from_seed(_seed: int) -> float:
	noise.seed = _seed
	return noise.get_noise_1d(time * noise_speed)

func set_fov(value: float):
	camera.fov = value

func recoil_fire():
	jerk_gun_backward()
	var final_recoil = recoil * recoil_power * GLOBAL_RECOIL_COEFFICIENT
	var recoil_vector = Vector3(final_recoil.x, randf_range(-final_recoil.y, final_recoil.y), randf_range(-final_recoil.z, final_recoil.z))
	target_rotation += recoil_vector
	rotation_velocity += recoil_vector
	recover_rotation_velocity = - rotation_velocity / 2

func set_recoil_vector(new_recoil: Vector3):
	recoil = new_recoil

func set_recoil_power(new_power: float):
	recoil_power = new_power

func jerk_gun_backward():
	var jerk_distance = recoil_power / JERK_GUN_DAMPING_FACTOR
	if jerk_gun_tween and jerk_gun_tween.is_running():
		jerk_gun_tween.stop()
	gun_container.position.z += jerk_distance # Move backward
	jerk_gun_tween = self.create_tween()
	jerk_gun_tween.tween_property(gun_container, "position", original_gun_container_pos, 0.2 + recoil_power).set_trans(Tween.TRANS_SINE)


func check_if_has_recoil():
	if rotation_velocity.length() < 0.1:
		return false
	return true
