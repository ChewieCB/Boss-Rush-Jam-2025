@tool
extends EditorScript

const JSON_PATH := "res://Spiral.001.json"
const BAKE_INTERVAL := 0.05


func _run() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		push_error("Open a scene.")
		return

	# Parse the json file
	var file := FileAccess.open(JSON_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open %s" % JSON_PATH)
		return
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or not data.has("splines"):
		push_error("JSON not in the expected format.")
		return
	
	# Note the currently selected node to add the curve as a child of
	var parent: Node = root
	var selected := EditorInterface.get_selection().get_selected_nodes()
	if not selected.is_empty() and selected[0] is Node3D:
		parent = selected[0]
	
	# Read curve data from the json
	var splines: Array = data["splines"]
	for i in splines.size():
		var spline: Dictionary = splines[i]
		var curve := Curve3D.new()
		curve.bake_interval = BAKE_INTERVAL
		
		for _point in spline["points"]:
			curve.add_point(
				_vert(_point["p"]),
				_vert(_point["in"]),
				_vert(_point["out"])
			)
		
		if spline.get("closed", false) and curve.point_count > 2:
			# Repeat the first point to close the loop.
			var first: Dictionary = spline["points"][0]
			curve.add_point(
				_vert(first["p"]),
				_vert(first["in"]),
				_vert(first["out"])
			)
		
		var path := Path3D.new()
		var base := str(data.get("name", "Curve"))
		path.name = base + "_Path" if splines.size() == 1 else "%s_Path%d" % [base, i]
		path.curve = curve
		parent.add_child(path, true)
		path.owner = root
		print("Created ", path.name, ": ", curve.point_count, " points, length ", snappedf(curve.get_baked_length(), 0.001))


func _vert(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])
