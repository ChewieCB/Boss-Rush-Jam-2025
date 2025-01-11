extends Node3D
class_name BaseProjectile

@export var spark_effect: PackedScene
@export var generic_blood_splatter: PackedScene

signal damage_applied
signal impacted
signal destroyed

var damage = 1
var ricochet_count_left = 0
var owner_gun: Gun
var is_ricochet_shot = false
var homing_strength = 0 # radius to search for enemy
var homing_locked_in = false
var homing_target = null

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


func ricochet():
	return
