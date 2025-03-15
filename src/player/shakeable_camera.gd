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

const MAX_TRAUMA = 2.0
const SHAKE_COEFFICIENT = 1.0
const DAMPING_FACTOR = 10
const GLOBAL_RECOIL_COEFFICIENT = 10

var trauma = 0.0
var long_trauma = 0.0 # Trauma over a long duration
var time = 0.0
var current_rotation: Vector3
var target_rotation: Vector3
var rotation_velocity: Vector3
var recoil_power: float = 0

func _process(delta):
	# Trauma
	time += delta
	trauma = max(trauma - delta * trauma_reduction_rate, 0.0)
	var final_trauma = clamp(trauma + long_trauma, 0.0, MAX_TRAUMA)

	camera.rotation_degrees.x = initial_rotation.x + max_x * get_shake_intensity(final_trauma) * get_noise_from_seed(0)
	camera.rotation_degrees.y = initial_rotation.y + max_y * get_shake_intensity(final_trauma) * get_noise_from_seed(1)
	camera.rotation_degrees.z = initial_rotation.z + max_z * get_shake_intensity(final_trauma) * get_noise_from_seed(2)

	# Recoil
	rotation_velocity -= rotation_velocity * DAMPING_FACTOR * delta
	rotation += rotation_velocity * delta

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
	var final_recoil = recoil * recoil_power * GLOBAL_RECOIL_COEFFICIENT
	var recoil_vector = Vector3(final_recoil.x, randf_range(-final_recoil.y, final_recoil.y), randf_range(-final_recoil.z, final_recoil.z))
	target_rotation += recoil_vector
	rotation_velocity += recoil_vector

func set_recoil_vector(new_recoil: Vector3):
	recoil = new_recoil

func set_recoil_power(new_power: float):
	recoil_power = new_power
