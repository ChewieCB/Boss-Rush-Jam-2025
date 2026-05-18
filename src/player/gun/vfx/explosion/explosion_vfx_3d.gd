extends Node3D
class_name ExplosionVFX3D

@export var original_fire_radius: float
@export var original_fire_height: float
@export var original_smoke_radius: float
@export var original_smoke_height: float

@onready var fire: GPUParticles3D = $Fire
@onready var smoke: GPUParticles3D = $Smoke

var count = 0

signal finished

func _ready() -> void:
	fire.draw_pass_1.radius = original_fire_radius
	smoke.draw_pass_1.radius = original_smoke_radius
	fire.finished.connect(check_count)
	smoke.finished.connect(check_count)
	smoke.emitting = true
	fire.emitting = true


#func change_mesh_scale(new_scale):
	#fire.draw_pass_1.radius = original_fire_radius * new_scale
	#fire.draw_pass_1.height = original_fire_height * new_scale
	#smoke.draw_pass_1.radius = original_smoke_radius * new_scale
	#smoke.draw_pass_1.height = original_smoke_height * new_scale

func check_count():
	count += 1
	if count >= 2:
		finished.emit()
		call_deferred('queue_free')
