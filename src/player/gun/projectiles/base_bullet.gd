extends Node3D
class_name BaseBullet

@export var spark_effect: PackedScene
@export var generic_blood_splatter: PackedScene
@export var bullet_decal_prefab: PackedScene
# Check BossCore.BossStatusEffect for order
@export var elemental_emitting_vfx: Array[Node3D] = [null, null, null, null, null] # VFX that emit as long as bullet/ray persist
@export var elemental_impact_vfx: Array[PackedScene] = [null, null, null, null, null] # VFX that trigger upon impact

signal before_damage_applied(enemy: CharacterBody3D, projectile: BaseBullet)
signal damage_applied(damage: float, has_pos: bool, pos: Vector3)
signal impacted(projectile: BaseBullet, has_pos: bool, pos: Vector3)
signal destroyed(hit_boss: bool)

const DAMAGE_VARIANCE = 0.2
const GRAVITY_FORCE = -9.8

## Base damage / initial damage
var damage = 1
## In decimal
var crit_chance = 0
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
var velocity: Vector3
var max_range
var splitted = false
var is_hitscan = false
var infused_status_effect = [false, false, false, false, false]
var can_be_aim_guided = false # or Laser-guided, homing to where player is aiming at
var min_lifetime_before_can_be_aim_guided = 0.2

var keep_alive: bool = false

# Statistics tracking for barrel effect
var color_changed_count = 0
var life_time = 0
var spawn_pos = Vector3.ZERO
var travelled_distance = 0
var hit_boss = false
var is_crit = false


func _ready() -> void:
	spawn_pos = global_position
	life_time = 0
	crit_chance = GameManager.player.current_stats[StatusEffect.PlayerStatEnum.CRITICAL_HIT_CHANCE]
	for elem in elemental_emitting_vfx:
		if elem:
			elem.visible = false


func init(_start_pos: Vector3, _dir: Vector3, _damage: int, _ricochet_count: int, _speed: float, _max_range: float) -> void:
	push_error("BaseBullet sub-class does not have an init method set.")


func _process(delta: float) -> void:
	life_time += delta

func create_spark(pos: Vector3, normal: Vector3):
	create_status_effect_impact(pos, normal)
	if spark_effect == null:
		return
	if can_be_aim_guided:
		pos = global_position
		normal = Vector3.UP

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
	create_status_effect_impact(pos, normal)
	if generic_blood_splatter == null:
		return
	if can_be_aim_guided:
		pos = global_position
		normal = Vector3.UP

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
	if can_be_aim_guided:
		pos = global_position
		normal = Vector3.UP

	var decal_inst = bullet_decal_prefab.instantiate()
	get_tree().get_root().add_child(decal_inst)
	decal_inst.global_position = pos

	if abs(normal.dot(Vector3.UP)) < 0.999:
		decal_inst.look_at(pos + normal, Vector3.UP)
		decal_inst.rotate_object_local(Vector3(1, 0, 0), 90)

	# Rotate the decal a bit for variety
	decal_inst.rotate_object_local(Vector3(0, 1, 0), randf_range(0.0, 360.0))

func create_status_effect_impact(pos: Vector3, normal: Vector3):
	var impact_effect = null
	for i in range(len(infused_status_effect)):
		if infused_status_effect[i] and elemental_impact_vfx[i]:
			impact_effect = elemental_impact_vfx[i]
			var impact_inst = impact_effect.instantiate()
			get_parent().add_child(impact_inst)
			impact_inst.global_position = pos

			if abs(normal.dot(Vector3.UP)) < 0.999:
				impact_inst.look_at(pos + normal, Vector3.UP)
				impact_inst.rotate_object_local(Vector3(1, 0, 0), 90)

func calculate_bullet_damage(reroll_crit = true):
	var rand_damage_mod = get_damage_variance_modifier(damage)
	var calculated_damage = damage + rand_damage_mod
	# Crit
	if reroll_crit:
		var roll = randi_range(1, 100)
		var roll_target = int(crit_chance * 100)
		if roll <= roll_target:
			calculated_damage = calculated_damage * GameManager.player.current_stats[StatusEffect.PlayerStatEnum.CRITICAL_HIT_DAMAGE_MULTIPLIER]
			owner_gun.crit_damage(calculated_damage)
			is_crit = true
	return calculated_damage

func ricochet():
	return

## This will be added to normal damage
func get_damage_variance_modifier(_damage: int) -> int:
	var min_variance = GameManager.player.current_stats[StatusEffect.PlayerStatEnum.MIN_DAMAGE_VARIANCE] - 1
	var max_variance = GameManager.player.current_stats[StatusEffect.PlayerStatEnum.MAX_DAMAGE_VARIANCE] - 1
	return int(randf_range(_damage * min_variance, _damage * max_variance))

func create_duplication(is_ricochet: bool = true) -> BaseBullet:
	var new_inst: BaseBullet = self.duplicate()
	new_inst.owner_gun = owner_gun
	new_inst.is_ricochet_shot = is_ricochet
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
		# Splitted bullet CAN NOT ricochet or split again
		new_inst.splitted = true
		new_inst.init(new_pos, new_dir, int(damage / split_count), 0, projectile_speed, max_range)


func change_bullet_color(_new_color: Color):
	color_changed_count += 1


func infuse_status_effect(_status_effect: BossCore.BossStatusEffect):
	infused_status_effect[int(_status_effect) - 1] = true


func stop_elemental_particles():
	for elem in elemental_emitting_vfx:
		if is_instance_valid(elem):
			elem.queue_free_after_time()

func applied_emitting_elemental_vfx(status_effect: BossCore.BossStatusEffect):
	# Wait a bit to make the effect look better
	await get_tree().create_timer(0.05).timeout
	var element_vfx_node = elemental_emitting_vfx[int(status_effect) - 1]
	if element_vfx_node:
		element_vfx_node.visible = true
		if element_vfx_node.has_method("turn_on"):
			element_vfx_node.turn_on()


func apply_damage_to_health_component(health_component: HealthComponent, damage_value: int):
	const CRIT_TEXT_SCALE_POP = 2.0
	const CRIT_TEXT_COLOR = Color(1, 0.4, 0)
	if is_crit:
		health_component.damage(damage_value, CRIT_TEXT_COLOR, CRIT_TEXT_SCALE_POP)
	else:
		health_component.damage(damage_value)
