extends Node3D
class_name RecoilCameraWrapper

@export var recoil: Vector3
@export var recoil_power: float = 0.3

var current_rotation: Vector3
var target_rotation: Vector3
var rotation_velocity: Vector3

const DAMPING_FACTOR = 5

func _process(delta):
    # Apply damping to stabilize motion
    rotation_velocity -= rotation_velocity * DAMPING_FACTOR * delta
    
    # Apply velocity to rotation
    target_rotation += rotation_velocity * delta
    
    # Set rotation
    rotation = target_rotation

func recoil_fire():
    var final_recoil = recoil * recoil_power
    var recoil_vector = Vector3(final_recoil.x, randf_range(-final_recoil.y, final_recoil.y), randf_range(-final_recoil.z, final_recoil.z))

    # Apply recoil impulse
    target_rotation += recoil_vector
    rotation_velocity += recoil_vector

func set_recoil_vector(new_recoil: Vector3):
    recoil = new_recoil

func set_recoil_power(new_power: float):
    recoil_power = new_power