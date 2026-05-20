extends Node3D
class_name ChiptopedeSegment

@export var rotation_speed: float = 5.0
@onready var mesh: MeshInstance3D = $Cylinder
@onready var splash_particles: GPUParticles3D = $SplashParticles
@onready var splash_ring_particles: GPUParticles3D = $SplashParticles/SplashRingParticle

var big_stack: BossChips
var segment_idx: int = -1  # Set by BossChips on spawn, used for damage lookup


func _ready() -> void:
	self.rotation.z = randf_range(0, 2*PI)


func tick(delta: float) -> void:
	self.rotation.z += rotation_speed * delta
