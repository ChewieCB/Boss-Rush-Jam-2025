extends Node3D
class_name Gun

@export var gun_name: String
@export_multiline var description: String

@export var base_damage = 10
@export var base_projectile_amount = 1
## Shot per second
@export var base_firerate = 2
@export var base_magazine_size = 10
## How spread out projectile can be from the aim center
@export var spread_angle = 0
## Projectile dont have travel time. Shot enemy is instanly damaged. If this ticked, ignore projectile_speed
@export var is_hitscan: bool
## How fast projectile travel. Ignored if is_hitscan ticked
@export var base_projectile_speed: float = 100
@export var recoil_amount: float = 0.03
## How much screenshake when player shot
@export var screenshake_amount: float = 0.2

@export var aim_ray_prefab: PackedScene
@export var projectile_prefab: PackedScene

@onready var barrel_container = $Barrel
@onready var gun_status_label: Label3D = $PlaceholderUI/StatusLabel
@onready var bullet_spawn_marker = $BulletStartPos
@onready var jam_timer: Timer = $JamTimer

var magazine_ammo_left = 0
var is_reloading = false
var is_jammed = false
var time_since_last_shot = 0
var installed_barrels: Array[SpinBarrel] = []

# Modify-able by barrels
# We won't modify them in this script
var n_ammo_consume = 1
var n_shot_repeat = 1
var modified_damage
var modified_projectile_amount
var modified_firerate
var modified_magazine_size

signal gun_shot
signal gun_reloaded


const MIN_DELAY_BETWEEN_SHOT_IN_BURST = 0.15
const BULLET_SPAWN_POS_VARIATION = 10

func _ready() -> void:
	gun_status_label.visible = false
	magazine_ammo_left = base_magazine_size
	for child in barrel_container.get_children():
		child.owner_gun = self
		installed_barrels.append(child)
	reset_modifier()

func _process(delta: float) -> void:
	time_since_last_shot += delta

func shoot(aim_ray: RayCast3D):
	if is_reloading or is_jammed:
		return
	if magazine_ammo_left <= 0:
		reload()
		return

	var can_fire = true
	for barrel in installed_barrels:
		can_fire = can_fire and barrel.get_active_effect().on_fire_attempt()
	if not can_fire:
		return

	for barrel in installed_barrels:
		barrel.get_active_effect().on_fire_rate_check()

	var time_until_next_shot = 1.0 / modified_firerate
	if time_until_next_shot > time_since_last_shot:
		return

	for barrel in installed_barrels:
		barrel.get_active_effect().on_prepare_to_fire()

	# Screenshake
	GameManager.player.player_camera.add_trauma(screenshake_amount)
	# Recoil
	GameManager.player.player_camera.rotate_x(recoil_amount)
	GameManager.player.player_camera.rotate_y(randf_range(-recoil_amount, recoil_amount))

	for barrel in installed_barrels:
		barrel.get_active_effect().on_damage_calculation()

	for i in range(n_shot_repeat):

		for j in range(modified_projectile_amount):
			for barrel in installed_barrels:
				barrel.get_active_effect().on_projectile_spawn()

			if is_hitscan:
				var aim_direction = aim_ray.aim_ray_end.global_position - bullet_spawn_marker.global_position
				var spread_direction = get_spread_direction(aim_direction)
				var bullet_start_pos = bullet_spawn_marker.global_position
				# Randomize bullet start pos a bit for automatic weapon
				# bullet_start_pos.x += randf_range(-screenshake_amount / BULLET_SPAWN_POS_VARIATION, screenshake_amount / BULLET_SPAWN_POS_VARIATION)
				# bullet_start_pos.y += randf_range(-screenshake_amount / BULLET_SPAWN_POS_VARIATION, screenshake_amount / BULLET_SPAWN_POS_VARIATION)
				create_hitscan_attack(bullet_start_pos, spread_direction, modified_damage)

			# TODO:
			# var projectile = null
			# projectile.impact.connect(check_barrel_effect_on_projectile_impact)
			# projectile.destroyed.connect(check_barrel_effect_on_projectile_destroyed)
		time_since_last_shot = 0
		await get_tree().create_timer(MIN_DELAY_BETWEEN_SHOT_IN_BURST).timeout

		for barrel in installed_barrels:
			barrel.get_active_effect().on_ammo_consumed()

	magazine_ammo_left -= n_ammo_consume
	for barrel in installed_barrels:
		barrel.get_active_effect().on_ammo_consumed()
	if magazine_ammo_left <= 0:
		for barrel in installed_barrels:
			barrel.get_active_effect().on_clip_empty()
	gun_shot.emit()
	reset_modifier()


func create_hitscan_attack(start_pos: Vector3, direction: Vector3, damage: int):
	var hitscan_ray: AimRay = aim_ray_prefab.instantiate()
	get_parent().add_child(hitscan_ray)
	hitscan_ray.global_position = start_pos
	hitscan_ray.look_at(start_pos + direction)
	var projectile_inst: BaseProjectile = projectile_prefab.instantiate()
	await get_tree().physics_frame
	await get_tree().physics_frame
	if hitscan_ray.is_colliding():
		var target = hitscan_ray.get_collider()
		var hitscan_col_point = hitscan_ray.get_collision_point()
		var hitscan_col_normal = hitscan_ray.get_collision_normal()
		projectile_inst.init(start_pos, hitscan_col_point)
		GameManager.player.get_parent().add_child(projectile_inst)
		if target is CharacterBody3D:
			target.health_component.damage(damage)
			projectile_inst.create_blood_splatter(hitscan_col_point, hitscan_col_normal)
			for barrel in installed_barrels:
				barrel.get_active_effect().on_damage_applied()

		else:
			# Hit wall/obstacle
			projectile_inst.create_spark(hitscan_col_point, hitscan_col_normal)
		# This is for ricohect. Not yet implemented
		# if bounce_left > 0:
		# 	create_hitscan_attack(hitscan_col_point, direction.bounce(hitscan_col_normal), bounce_left - 1, gun_projectile, damage)
	else:
		projectile_inst.init(start_pos, hitscan_ray.aim_ray_end.global_position)
		GameManager.player.get_parent().add_child(projectile_inst)
	hitscan_ray.call_deferred("queue_free")


func check_barrel_effect_on_projectile_impact():
	for barrel in installed_barrels:
		barrel.get_active_effect().on_projectile_impact()


func check_barrel_effect_on_projectile_destroyed():
	for barrel in installed_barrels:
		barrel.get_active_effect().on_projectile_destroyed()


func reload():
	if is_jammed:
		return
	for barrel in installed_barrels:
		barrel.get_active_effect().on_reload_start()

	is_reloading = true
	gun_status_label.text = "Reloading..."
	gun_status_label.visible = true
	reset_modifier()
	for barrel in installed_barrels:
		barrel.start_spin()
	await get_tree().create_timer(1).timeout
	gun_status_label.visible = false
	for barrel in installed_barrels:
		barrel.stop_spin()
	is_reloading = false

	for barrel in installed_barrels:
		barrel.get_active_effect().on_reload_end()


	magazine_ammo_left = modified_magazine_size
	gun_reloaded.emit()

func reset_modifier():
	n_ammo_consume = 1
	n_shot_repeat = 1
	modified_damage = base_damage
	modified_projectile_amount = base_projectile_amount
	modified_firerate = base_firerate
	modified_magazine_size = base_magazine_size


func jam_the_gun(duration: float = 1.0):
	gun_status_label.text = "Jamming..."
	gun_status_label.visible = true
	jam_timer.start(duration)
	is_jammed = true


func _on_jam_timer_timeout() -> void:
	gun_status_label.visible = false
	is_jammed = false


func get_spread_direction(center_direction: Vector3) -> Vector3:
	# Convert spread angle to radians
	var max_radians = deg_to_rad(spread_angle)

	# Generate random rotation within the spread cone
	var random_yaw = randf_range(-max_radians, max_radians)
	var random_pitch = randf_range(-max_radians, max_radians)

	# Create a rotation basis
	var spread_rotation = Basis(Vector3.UP, random_yaw) * Basis(Vector3.RIGHT, random_pitch)

	# Apply the rotation to the center direction
	return (spread_rotation * center_direction).normalized()
