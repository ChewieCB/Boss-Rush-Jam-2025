extends Node3D

@export var gpu_particles_arr: Array[GPUParticles3D] = []
@export var time_until_queue_free: float = 2.0

signal finished

func _ready() -> void:
	explosion()

func explosion():
	for elem in gpu_particles_arr:
		elem.emitting = true
	await get_tree().create_timer(time_until_queue_free).timeout
	finished.emit()
	queue_free()
