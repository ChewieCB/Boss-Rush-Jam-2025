@tool
extends Node3D
class_name ExplosionParticles

@export var gpu_particles_arr: Array[GPUParticles3D] = []
@export var scale_factor: float = 1.0:
	set(value):
		scale_factor = value
		min_scale = scale_factor
		max_scale = 1.5 * scale_factor
		emission_radius = scale_factor
@export var min_scale: float = 1.0
@export var max_scale: float = 1.5
@export var emission_radius: float = 1.0
@export var explode_on_spawn: bool = true
@export var free_on_finished: bool = true
@export var emitting: bool = false:
	set(value):
		emitting = value
		explosion()
		emitting = false

@export var time_until_queue_free: float = 2.0


func _ready() -> void:
	if explode_on_spawn:
		explosion()


func explosion():
	for elem in gpu_particles_arr:
		elem.process_material.scale_min = min_scale
		elem.process_material.scale_max = max_scale
		elem.process_material.emission_sphere_radius = emission_radius
		elem.restart()
		elem.emitting = true
	
	if free_on_finished:
		await get_tree().create_timer(time_until_queue_free).timeout
		queue_free()
