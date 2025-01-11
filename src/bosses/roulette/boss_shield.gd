extends StaticBody3D
class_name Shield

@export var shield_mesh: MeshInstance3D

const SHIELD_IMPACT_DECAY_SPEED: float = 1

var _points: PointBuffer = PointBuffer.new(16)

func _ready() -> void:
	shield_mesh.material_override = shield_mesh.material_override.duplicate()


func _process(delta: float) -> void:
	var decayed_points: Array[Vector4] = _points.decay_points(delta, SHIELD_IMPACT_DECAY_SPEED)
	shield_mesh.material_override.set("shader_parameter/impact_points", decayed_points)


func impact(impact_pos: Vector3) -> void:
	_points.push(to_local(impact_pos))


class PointBuffer:
	var _buffer_index:int = 0
	var _points:Array[Vector4]
	
	func _init(buffer_size:int) -> void:
		_points.resize(buffer_size)
	
	func push(point:Vector3) -> void:
		_points[_buffer_index] = Vector4(point.x, point.y, point.z, 1.0)
		_buffer_index += 1
		if _buffer_index >= _points.size():
			_buffer_index = 0

	func decay_points(delta:float, decay_speed:float) -> Array[Vector4]:
		var new_points:Array[Vector4]
		for point in _points:
			new_points.append(Vector4(point.x, point.y, point.z, clamp(point.w - decay_speed * delta, 0, 1)))
		_points = new_points
		
		return _points
