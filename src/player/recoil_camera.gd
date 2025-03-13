extends Node3D
class_name RecoilCameraWrapper

@export var recoil: Vector3
@export var recoil_power: float = 0.3
@export var snappiness: float = 2.0
@export var return_speed: float = 10.0

var current_rotation: Vector3
var target_rotation: Vector3

func _process(delta):
	# Lerp target rotation to (0,0,0) and lerp current rotation to target rotation
	target_rotation = lerp(target_rotation, Vector3.ZERO, return_speed * delta)
	current_rotation = lerp(current_rotation, target_rotation, snappiness * delta)

	# Set rotation
	rotation = current_rotation

func recoil_fire():
	var final_recoil = recoil
	target_rotation += Vector3(final_recoil.x, randf_range(-final_recoil.y, final_recoil.y), randf_range(-final_recoil.z, final_recoil.z))

func set_recoil_vector(new_recoil: Vector3):
	recoil = new_recoil

func set_recoil_power(new_power: float):
	recoil_power = new_power
