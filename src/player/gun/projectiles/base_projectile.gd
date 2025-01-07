extends MeshInstance3D
class_name BaseProjectile

@export var spark_effect: PackedScene
@export var text_effect: PackedScene
@export var generic_blood_splatter: PackedScene

func create_spark(pos: Vector3, normal: Vector3):
	var spark_inst = spark_effect.instantiate()
	get_parent().add_child(spark_inst)
	spark_inst.global_position = pos

	if normal.is_equal_approx(Vector3.DOWN):
		spark_inst.rotation_degrees.x = -90
	elif normal.is_equal_approx(Vector3.UP):
		spark_inst.rotation_degrees.x = 90
	else:
		spark_inst.look_at(pos + normal, Vector3.UP)

func create_blood_splatter(pos: Vector3, normal: Vector3):
	var blood_inst = generic_blood_splatter.instantiate()
	get_parent().add_child(blood_inst)
	blood_inst.global_position = pos

	if normal.is_equal_approx(Vector3.DOWN):
		blood_inst.rotation_degrees.x = -90
	elif normal.is_equal_approx(Vector3.UP):
		blood_inst.rotation_degrees.x = 90
	else:
		blood_inst.look_at(pos + normal, Vector3.UP)


func create_text(pos: Vector3, normal: Vector3,
text: String, color: Color = Color.WHITE, size: float = 92.0) -> void:
	var text_inst = text_effect.instantiate()
	get_parent().add_child(text_inst)
	var variance = 0.5
	var rand_x = randf_range(-variance, variance)
	var rand_y = randf_range(-variance, variance)
	var rand_z = randf_range(-variance, variance)
	text_inst.text = text
	text_inst.modulate = color
	text_inst.font_size = size
	text_inst.outline_size = size / 2
	text_inst.global_position = pos + Vector3(rand_x, rand_y, rand_z)

	if normal.is_equal_approx(Vector3.DOWN):
		text_inst.rotation_degrees.x = -90
	elif normal.is_equal_approx(Vector3.UP):
		text_inst.rotation_degrees.x = 90
	else:
		text_inst.look_at(pos + normal, Vector3.UP)
