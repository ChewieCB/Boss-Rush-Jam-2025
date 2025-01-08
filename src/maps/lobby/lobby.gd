extends Node3D


var display_barrels: Array = []

func _ready() -> void:
	for node in $DisplayBarrels.get_children():
		var model = node.get_node("Model")
		model.rotation_degrees.y = randf_range(0, 360)
		display_barrels.append(model)


func _process(delta: float) -> void:
	for node in display_barrels:
		node.rotation.y += delta


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is Player:
		get_tree().change_scene_to_file("res://src/bosses/base/test/Test_BossCore.tscn")
