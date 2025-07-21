extends Node3D
class_name GPUParticleController

@export var is_oneshot = false
## Set to -1 to not self destroy
@export var self_destroy_after_time = -1
@export var gpu_particles: Array[GPUParticles3D]
@export var lights: Array[Light3D]
@export var time_until_queue_free = 1

const LIGHT_FADE_SPEED = 1

var turn_off_light = false

func _ready() -> void:
	if is_oneshot:
		turn_off_light = true
		for elem in gpu_particles:
			elem.emitting = true
	
	if self_destroy_after_time > 0:
		await get_tree().create_timer(self_destroy_after_time).timeout
		queue_free()

func turn_on():
	for elem in gpu_particles:
		elem.emitting = true

func turn_off():
	for elem in gpu_particles:
		elem.lifetime = 1
		elem.emitting = false


func smooth_turn_off():
	for elem in gpu_particles:
		elem.lifetime = 1
		elem.one_shot = true
		elem.emitting = false

func queue_free_after_time():
	turn_off_light = true
	reparent(get_tree().get_root())
	turn_off()
	await get_tree().create_timer(time_until_queue_free).timeout
	call_deferred("queue_free")

func _process(delta: float) -> void:
	if turn_off_light:
		for light in lights:
			light.light_energy -= LIGHT_FADE_SPEED * delta
			if light.light_energy < 0:
				light.light_energy = 0
