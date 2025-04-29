extends Node3D
class_name BaseProjectile

@export var spark_effect: PackedScene
@export var generic_blood_splatter: PackedScene
@export var bullet_decal_prefab: PackedScene

signal damage_applied(damage: float)
signal impacted
signal destroyed

var damage = 1
var ricochet_count_left = 0
var owner_gun: Gun
var is_ricochet_shot = false
var homing_strength = 0 # radius to search for enemy
var homing_locked_in = false
var homing_target = null
var delayed_time = 1

func create_spark(pos: Vector3, normal: Vector3):
	if spark_effect == null:
		return
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
	if generic_blood_splatter == null:
		return
	var blood_inst = generic_blood_splatter.instantiate()
	get_parent().add_child(blood_inst)
	blood_inst.global_position = pos

	if normal.is_equal_approx(Vector3.DOWN):
		blood_inst.rotation_degrees.x = -90
	elif normal.is_equal_approx(Vector3.UP):
		blood_inst.rotation_degrees.x = 90
	else:
		blood_inst.look_at(pos + normal, Vector3.UP)

func create_bullet_decal(pos: Vector3, normal: Vector3):
	if bullet_decal_prefab == null:
		return
	var decal_inst = bullet_decal_prefab.instantiate()
	get_tree().get_root().add_child(decal_inst)
	decal_inst.global_position = pos

	if normal != Vector3.UP and normal != Vector3.DOWN:
		decal_inst.look_at(pos + normal, Vector3.UP)
		decal_inst.rotate_object_local(Vector3(1, 0, 0), 90)
	
	# Rotate the decal a bit for variety
	decal_inst.rotate_object_local(Vector3(0, 1, 0), randf_range(0.0, 360.0))


func ricochet():
	return
