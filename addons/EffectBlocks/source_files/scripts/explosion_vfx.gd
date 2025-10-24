extends Node3D

@export var gpu_particles_arr: Array[GPUParticles3D] = []
@export var time_until_queue_free: float = 2.0

signal finished

func explode():
	for elem in gpu_particles_arr:
		elem.emitting = true
	await get_tree().create_timer(time_until_queue_free).timeout
	for elem in gpu_particles_arr:
		elem.emitting = false
	finished.emit()
