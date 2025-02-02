extends MeshInstance3D
class_name SlotRollerDecal

var decal_idx: int = 0
var is_scrolling: bool = true


func _ready() -> void:
	decal_idx = randi_range(0, 5)
	var uv_offset: float = 0.25 * randi_range(0, 5)
	mesh.material = mesh.material.duplicate()
	mesh.material.uv1_offset.y -= uv_offset


func _physics_process(delta: float) -> void:
	var current_uv_offset = mesh.material.uv1_offset
	var closest_uv_snap: float = snapped(current_uv_offset.y, 0.25)
	if is_scrolling:
		mesh.material.uv1_offset.y = lerp(
			mesh.material.uv1_offset.y, 
			closest_uv_snap + 0.25, 
			delta * 2.5
		)
	else:
		if is_equal_approx(mesh.material.uv1_offset.y, closest_uv_snap + decal_idx * 0.25):
			return
		else:
			mesh.material.uv1_offset.y = lerp(
				mesh.material.uv1_offset.y, 
				closest_uv_snap + decal_idx * 0.25, 
				delta * 4.0
			)
