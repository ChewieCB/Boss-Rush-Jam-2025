@tool
extends Marker3D
class_name SnakePositionMarker

@export var entProperties: Dictionary = {
	"marker_group": "snake_path",
}
var marker_group: String
@export var connected_points: Array[Marker3D]


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	marker_group = entProperties["marker_group"]
	add_to_group("boss_%s_marker" % marker_group)


func _func_godot_apply_properties(properties: Dictionary) -> void:
	entProperties = properties
