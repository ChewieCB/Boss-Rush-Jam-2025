extends Node3D
class_name BaseProjectile

@export var spark_effect: PackedScene
@export var generic_blood_splatter: PackedScene
@export var bullet_decal_prefab: PackedScene

signal before_damage_applied(enemy: CharacterBody3D, projectile: BaseProjectile)
signal damage_applied(damage: float, has_pos: bool, pos: Vector3)
signal impacted(projectile: BaseProjectile, has_pos: bool, pos: Vector3)
signal destroyed

const DAMAGE_VARIANCE = 0.2
const GRAVITY_FORCE = -9.8

var damage = 1
var ricochet_count_left = 0
var owner_gun: Gun
var is_ricochet_shot = false
var homing_strength = 0 # radius to search for enemy
var homing_locked_in = false
var homing_target = null
var delayed_time = 1
var found_hitscal_col = false
var hitscan_col_point: Vector3 = Vector3.ZERO
var hitscan_col_normal: Vector3 = Vector3.ZERO
var current_dir: Vector3
var projectile_speed = 100
var max_range
var splitted = false
var is_hitscan = false

# Statistics traking or barrel effect
var life_time = 0
var spawn_pos = Vector3.ZERO
var travelled_distance = 0


func _ready() -> void:
	spawn_pos = global_position
	life_time = 0

func _process(delta: float) -> void:
	life_time += delta

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

	if abs(normal.dot(Vector3.UP)) < 0.999:
		decal_inst.look_at(pos + normal, Vector3.UP)
		decal_inst.rotate_object_local(Vector3(1, 0, 0), 90)
	
	# Rotate the decal a bit for variety
	decal_inst.rotate_object_local(Vector3(0, 1, 0), randf_range(0.0, 360.0))


func ricochet():
	return

## This will be added to normal projectile attack
func get_damage_variance_modifier(_damage: int) -> int:
	if GameManager.player.luck_component.current_luck_ratio >= GameManager.player.HIGH_LUCK_THRESHOLD:
		# High luck will roll from 0 to 0.2 instead of usual -0.2 to 0.2
		return int(randf_range(0, _damage * DAMAGE_VARIANCE))
	return int(randf_range(_damage * -DAMAGE_VARIANCE, _damage * DAMAGE_VARIANCE))

func create_duplication() -> BaseProjectile:
	var new_inst: BaseProjectile = self.duplicate()
	new_inst.owner_gun = owner_gun
	new_inst.is_ricochet_shot = true
	new_inst.homing_strength = homing_strength
	new_inst.spawn_pos = spawn_pos
	new_inst.life_time = life_time
	new_inst.travelled_distance = travelled_distance
	new_inst.before_damage_applied.connect(owner_gun.check_barrel_effect_on_before_damage_applied)
	new_inst.damage_applied.connect(owner_gun.check_barrel_effect_on_damage_applied)
	new_inst.damage_applied.connect(LuckHandler.accumulate_dps_dealt.unbind(2))
	new_inst.impacted.connect(owner_gun.check_barrel_effect_on_projectile_impact)
	new_inst.destroyed.connect(owner_gun.check_barrel_effect_on_projectile_destroyed)
	return new_inst


func split(split_count: int, split_spread_radius: float, _has_pos: bool, _pos: Vector3):
	if splitted:
		return

	var center_dir = - current_dir
	var new_pos = global_position
	if found_hitscal_col:
		center_dir = hitscan_col_normal
	if _has_pos:
		new_pos = _pos

	for i in range(split_count):
		if not is_instance_valid(self):
			return
		var new_inst = create_duplication()
		get_tree().get_root().add_child(new_inst)
		var new_dir = GunUtils.get_spread_direction(center_dir, split_spread_radius)
		# Splitted bullet cant ricochet
		new_inst.splitted = true
		new_inst.init(new_pos, new_dir, int(damage / split_count), 0, projectile_speed, max_range)
