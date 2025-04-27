extends BossMap


func _ready() -> void:
	super()
	# Generate nav mesh
	var floor_static_body: StaticBody3D = func_godot_parent.find_child("entity_17_func_geo")
	var floor_mesh: MeshInstance3D = floor_static_body.get_child(0)
