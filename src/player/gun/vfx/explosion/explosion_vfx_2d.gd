extends Node3D
class_name ExplosionVFX2D

@export var original_fire_size: Vector2
@export var original_smoke_size: Vector2

@onready var fire: GPUParticles3D = $Fire
@onready var smoke: GPUParticles3D = $Smoke


var count = 0

signal finished

func _ready() -> void:
	fire.draw_pass_1.size = original_fire_size
	smoke.draw_pass_1.size = original_smoke_size
	fire.finished.connect(check_count)
	smoke.finished.connect(check_count)
	smoke.emitting = true
	fire.emitting = true


func change_mesh_scale(new_scale):
	fire.draw_pass_1.size = original_fire_size * new_scale
	smoke.draw_pass_1.size = original_smoke_size * new_scale


func set_colour(colour: Color) -> void:
	smoke.process_material.color = colour
	var hue: float = colour.h
	var fire_gradient: Gradient = fire.process_material.color_ramp.gradient
	for i in range(fire_gradient.get_point_count()):
		var _colour: Color = fire_gradient.get_color(i)
		_colour.h = hue
		fire.process_material.color_ramp.gradient.set_color(i, _colour)


func check_count():
	count += 1
	if count >= 2:
		finished.emit()
		call_deferred('queue_free')
