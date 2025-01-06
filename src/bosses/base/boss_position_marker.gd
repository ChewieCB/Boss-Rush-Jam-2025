@tool
extends Marker3D
class_name BossPositionMarker

@export var entProperties: Dictionary = {
	"marker_group": "",
}
var marker_group: String


func _ready() -> void:
	marker_group = entProperties["marker_group"]
	add_to_group("boss_%s_marker" % marker_group)
	
	var debug_mesh_instance = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	var sphere_mat = ORMMaterial3D.new()
	
	# Generate a visual
	get_tree().get_root().add_child(debug_mesh_instance)
	
	debug_mesh_instance.mesh = mesh
	debug_mesh_instance.cast_shadow = false
	debug_mesh_instance.global_position = self.global_position
	
	mesh.radius = 0.5
	mesh.material = sphere_mat
	
	#sphere_mat.transparency = true
	sphere_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere_mat.cull_mode = 2
	sphere_mat.albedo_color = Color(Color.PURPLE, 0.5)
	


func _func_godot_apply_properties(properties: Dictionary) -> void:
	entProperties = properties
