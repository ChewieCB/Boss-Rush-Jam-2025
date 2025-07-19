extends Node3D
class_name GPUParticleController

@export var gpu_particles: Array[GPUParticles3D]
@export var lights: Array[Light3D]
@export var time_until_queue_free = 1

const LIGHT_FADE_SPEED = 1

var turn_off_light = false

func turn_on():
	for elem in gpu_particles:
		elem.emitting = true

func turn_off():
	for elem in gpu_particles:
		elem.one_shot = true
		elem.emitting = false

	
func queue_free_after_time():
	turn_off_light = true
	reparent(get_tree().get_root())
	for elem in gpu_particles:
		elem.one_shot = true
		elem.lifetime = 1
	await get_tree().create_timer(time_until_queue_free).timeout
	call_deferred("queue_free")

func _process(delta: float) -> void:
	if turn_off_light:
		for light in lights:
			light.light_energy -= LIGHT_FADE_SPEED * delta
			if light.light_energy < 0:
				light.light_energy = 0
