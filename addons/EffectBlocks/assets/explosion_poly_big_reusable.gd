extends Node3D

@export var gpu_particles_arr: Array[GPUParticles3D] = []
@export var size: float = 1.0:
	set(value): 
		size = value
		for elem in gpu_particles_arr:
			elem.scale = Vector3(size, size, size) 


func explosion():
	for elem in gpu_particles_arr:
		elem.restart()
		elem.emitting = true
