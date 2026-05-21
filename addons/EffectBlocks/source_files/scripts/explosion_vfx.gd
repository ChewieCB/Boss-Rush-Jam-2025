@tool
extends Node3D
class_name ExplosionParticles

signal finished

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
@export var explode_on_spawn: bool = false
@export var free_on_finished: bool = false
@export var emitting: bool = false:
	set(value):
		emitting = value
		explode()
		emitting = false

@export var time_until_queue_free: float = 2.0
@onready var _root = get_tree().get_root()


func set_colour(colour: Color) -> void:
	for elem in gpu_particles_arr.slice(0, 2):
		elem.process_material.color = colour
		
		var hue: float = colour.h
		var gradient: Gradient = elem.process_material.color_ramp.gradient
		for i in range(gradient.get_point_count()):
			var _colour: Color = gradient.get_color(i)
			_colour.h = hue
			elem.process_material.color_ramp.gradient.set_color(i, _colour)


func reset_color() -> void:
	var elem = gpu_particles_arr.slice(0, 2)
	# Fire
	elem[0].process_material.color = Color("#ff9900")
	var gradient: Gradient = elem[0].process_material.color_ramp.gradient
	elem[0].process_material.color_ramp.gradient.set_color(0, Color("#ff9900"))
	# Sparks
	elem[1].process_material.color = Color("#ff7427")
	gradient = elem[1].process_material.color_ramp.gradient
	elem[1].process_material.color_ramp.gradient.set_color(0, Color("#e55800"))
	elem[1].process_material.color_ramp.gradient.set_color(1, Color("#ffff00"))


func explode(scale_factor: float = 1.0):
	for elem in gpu_particles_arr:
		elem.process_material.scale_min = min_scale * scale_factor
		elem.process_material.scale_max = max_scale * scale_factor
		elem.process_material.emission_sphere_radius = emission_radius
		elem.restart()
		elem.emitting = true
	
	if free_on_finished:
		await get_tree().create_timer(time_until_queue_free).timeout
		finished.emit()
		queue_free()
	else:
		await get_tree().create_timer(time_until_queue_free).timeout
		finished.emit()


func activate() -> void:
	self.visible = true
	self.process_mode = Node.PROCESS_MODE_INHERIT
	explode()


func deactivate() -> void:
	self.visible = false
	for elem in gpu_particles_arr:
		elem.emitting = false
	
	if get_parent() != _root:
		self.reparent(_root)
	
	reset_color()
	self.process_mode = Node.PROCESS_MODE_DISABLED
