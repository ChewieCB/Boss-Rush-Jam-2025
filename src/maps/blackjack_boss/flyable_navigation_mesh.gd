extends Node3D

@export var mesh: MeshInstance3D

func get_points() -> Array:
	var arrays = mesh.mesh.surface_get_arrays(0)
	var vertices = arrays[0]
	var unique_vertices: Array = []
	
	for vert in vertices:
		if not unique_vertices.has(vert + self.global_position):
			unique_vertices.append(vert + self.global_position)
	
	return unique_vertices
