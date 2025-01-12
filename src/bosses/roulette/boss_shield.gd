extends StaticBody3D
class_name Shield

signal destroyed

@export var shield_mesh: MeshInstance3D
@export var health_component: HealthComponent

const SHIELD_IMPACT_DECAY_SPEED: float = 1

var _points: PointBuffer = PointBuffer.new(16)


func _ready() -> void:
	shield_mesh.material_override = shield_mesh.material_override.duplicate()
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)


func _process(delta: float) -> void:
	var decayed_points: Array[Vector4] = _points.decay_points(delta, SHIELD_IMPACT_DECAY_SPEED)
	shield_mesh.material_override.set("shader_parameter/impact_points", decayed_points)


func impact(impact_pos: Vector3) -> void:
	_points.push(to_local(impact_pos))


func _on_health_changed(new_health: float, _prev_health: float) -> void:
	# Map the current health to max health and change the shield colour from
	# blue to yellow to orange to red
	var health_perc: float = new_health / health_component.max_health
	var current_color: Color = shield_mesh.material_override.get("shader_parameter/color")
	var low_color: Color
	if new_health / health_component.max_health > 0.5:
		low_color = Color.YELLOW
	else:
		low_color = Color.RED
	var new_shield_color := low_color.lerp(current_color, health_perc)
	set_shield_color(new_shield_color)


func set_shield_color(value: Color) -> void:
	shield_mesh.material_override.set("shader_parameter/color", value)


func _on_died() -> void:
	# TODO - add some particle effects or a burst or something
	destroyed.emit()
	var current_color: Color = shield_mesh.material_override.get("shader_parameter/color")
	var tween = get_tree().create_tween()
	tween.tween_method(
		set_shield_color, 
		current_color,
		Color(current_color, 0),
		0.5,
	)
	tween.tween_callback(self.queue_free)


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
