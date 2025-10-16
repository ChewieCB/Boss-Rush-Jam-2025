extends Node3D

@export var mesh: MeshInstance3D
@export var particles: GPUParticles3D

@onready var material: StandardMaterial3D = mesh.mesh.surface_get_material(0)
