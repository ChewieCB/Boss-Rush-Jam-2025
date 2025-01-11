extends Node3D
class_name Gun

@export var gun_name: String
@export_multiline var description: String

## TEMP SFX PLS CHANGE
@export var TEMP_sfx_shoot: AudioStream
@export var TEMP_sfx_dry: AudioStream
@export var TEMP_sfx_reload: AudioStream
@export var TEMP_sfx_click: AudioStream
@export var TEMP_regain_ammo: AudioStream
@export var TEMP_crit: AudioStream

@export var base_damage = 10
@export var base_projectile_amount = 1
## Shot per second
@export var base_firerate = 2
@export var base_magazine_size = 10
@export var base_reload_time = 1
## How spread out projectile can be from the aim center
@export var base_spread_angle = 0
## Projectile dont have travel time. Shot enemy is instanly damaged. If this ticked, ignore projectile_speed
@export var is_hitscan: bool
## How fast projectile travel. Ignored if is_hitscan ticked. Shouldn't higher than 100 or collision detecion
## will be an issue
@export var base_projectile_speed: float = 100
@export var recoil_amount: float = 0.03
## How much screenshake when player shot
@export var screenshake_amount: float = 0.2

@export var aim_ray_prefab: PackedScene
@export var hiscan_prefab: PackedScene
@export var projectile_prefab: PackedScene

@onready var barrel_container = $Barrel
@onready var gun_status_label: Label3D = $PlaceholderUI/StatusLabel
@onready var bullet_spawn_marker = $BulletStartPos
@onready var jam_timer: Timer = $JamTimer
@onready var failed_shoot_sfx_timer: Timer = $FailToShootSFXTimer

var magazine_ammo_left = 0
var is_reloading = false
var is_jammed = false
var time_since_last_shot = 0
var installed_barrels: Array[SpinBarrel] = []
var is_trigger_pulled = false

# Modify-able by barrels
# We won't modify them in this script
var n_ammo_consume = 1
var n_shot_repeat = 1
var modified_damage
var modified_projectile_amount
var modified_firerate
var modified_magazine_size
var modified_projectile_speed
var modified_is_hitscan
var modified_spread_angle
var modified_reload_time

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
	reset_modifier(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	reload()

func _process(delta: float) -> void:
	time_since_last_shot += delta


## Return true if shot successful
func shoot(aim_ray: RayCast3D):
	if is_reloading or is_jammed:
		play_failed_shoot_sfx()
		return
	if magazine_ammo_left <= 0:
		play_failed_shoot_sfx()
		reload()
		return

	var time_until_next_shot = 1.0 / modified_firerate
	if time_until_next_shot > time_since_last_shot:
		return

	reset_modifier()

	var can_fire = true
	for barrel in installed_barrels:
		can_fire = can_fire and barrel.get_active_effect().on_fire_attempt()
	if not can_fire:
		play_failed_shoot_sfx()
		return

	for barrel in installed_barrels:
		barrel.get_active_effect().on_fire_rate_check()

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
		var bullet_start_pos = bullet_spawn_marker.global_position
		SoundManager.play_sound(TEMP_sfx_shoot)
		for j in range(modified_projectile_amount):

			for barrel in installed_barrels:
				barrel.get_active_effect().on_projectile_spawn()
			var aim_direction = aim_ray.aim_ray_end.global_position - bullet_spawn_marker.global_position
			var spread_direction = get_spread_direction(aim_direction)
			# Randomize bullet start pos a bit for automatic weapon
			# bullet_start_pos.x += randf_range(-screenshake_amount / BULLET_SPAWN_POS_VARIATION, screenshake_amount / BULLET_SPAWN_POS_VARIATION)
			# bullet_start_pos.y += randf_range(-screenshake_amount / BULLET_SPAWN_POS_VARIATION, screenshake_amount / BULLET_SPAWN_POS_VARIATION)
			if modified_is_hitscan:
				create_hitscan_attack(bullet_start_pos, spread_direction, modified_damage)
			else:
				create_projectile_attack(bullet_start_pos, spread_direction, modified_damage, modified_projectile_speed)

			# TODO:
			# var projectile = null
			# projectile.impact.connect(check_barrel_effect_on_projectile_impact)
			# projectile.destroyed.connect(check_barrel_effect_on_projectile_destroyed)
		time_since_last_shot = 0
		if n_shot_repeat > 1:
			await get_tree().create_timer(MIN_DELAY_BETWEEN_SHOT_IN_BURST).timeout

	magazine_ammo_left -= n_ammo_consume
	for barrel in installed_barrels:
		barrel.get_active_effect().on_ammo_consumed()
	if magazine_ammo_left <= 0:
		for barrel in installed_barrels:
			barrel.get_active_effect().on_clip_empty()
	gun_shot.emit()


func create_hitscan_attack(start_pos: Vector3, direction: Vector3, damage: int, max_range: float = 500):
	var projectile_inst: GunHitscan = hiscan_prefab.instantiate()
	GameManager.player.get_parent().add_child(projectile_inst)
	projectile_inst.init(start_pos, direction, damage, max_range)
	projectile_inst.damage_applied.connect(check_barrel_effect_on_damage_applied)
	projectile_inst.impacted.connect(check_barrel_effect_on_projectile_impact)
	projectile_inst.destroyed.connect(check_barrel_effect_on_projectile_destroyed)


func create_projectile_attack(start_pos: Vector3, direction: Vector3, damage: int, speed: float):
	var projectile_inst: GunProjectile = projectile_prefab.instantiate()
	GameManager.player.get_parent().add_child(projectile_inst)
	projectile_inst.init(start_pos, direction, damage, speed)
	projectile_inst.damage_applied.connect(check_barrel_effect_on_damage_applied)
	projectile_inst.impacted.connect(check_barrel_effect_on_projectile_impact)
	projectile_inst.destroyed.connect(check_barrel_effect_on_projectile_destroyed)

func check_barrel_effect_on_damage_applied():
	for barrel in installed_barrels:
		barrel.get_active_effect().on_damage_applied()

func check_barrel_effect_on_projectile_impact(_has_pos: bool = false, _pos: Vector3 = Vector3.ZERO):
	for barrel in installed_barrels:
		barrel.get_active_effect().on_projectile_impact(_has_pos, _pos)

func check_barrel_effect_on_projectile_destroyed():
	for barrel in installed_barrels:
		barrel.get_active_effect().on_projectile_destroyed()

func pull_trigger():
	if not is_trigger_pulled:
		is_trigger_pulled = true
		for barrel in installed_barrels:
			barrel.get_active_effect().on_trigger_pulled()

func release_trigger():
	if is_trigger_pulled:
		is_trigger_pulled = false
		for barrel in installed_barrels:
			barrel.get_active_effect().on_trigger_released()


func reload():
	if is_reloading:
		return
	if is_jammed:
		play_failed_shoot_sfx()
		return
	
	release_trigger()

	for barrel in installed_barrels:
		barrel.get_active_effect().on_reload_start()

	is_reloading = true
	SoundManager.play_sound(TEMP_sfx_reload)
	show_gun_status("Reloading...")
	for barrel in installed_barrels:
		barrel.start_spin()
	await get_tree().create_timer(modified_reload_time).timeout
	reset_modifier(true)
	gun_status_label.visible = false
	for barrel in installed_barrels:
		SoundManager.play_sound(TEMP_sfx_click)
		barrel.stop_spin()
	is_reloading = false

	for barrel in installed_barrels:
		barrel.get_active_effect().on_reload_end()

	magazine_ammo_left = modified_magazine_size
	gun_reloaded.emit()


func reset_modifier(reload_reset = false):
	n_ammo_consume = 1
	n_shot_repeat = 1
	modified_damage = base_damage
	modified_projectile_amount = base_projectile_amount
	modified_firerate = base_firerate
	modified_projectile_speed = base_projectile_speed
	modified_is_hitscan = is_hitscan
	modified_spread_angle = base_spread_angle
	if reload_reset:
		modified_reload_time = base_reload_time
		modified_magazine_size = base_magazine_size


func jam_the_gun(duration: float = 1.0):
	show_gun_status("Jammed...", Color.DIM_GRAY, duration)
	
	jam_timer.start(duration)
	is_jammed = true


# TODO - debug use only: make better, more interesting UI effects and hooks for this
func regain_ammo(ammo: int) -> void:
	show_gun_status("Regained +%s ammo" % [ammo], Color.CYAN)
	SoundManager.play_sound(TEMP_regain_ammo)


# TODO - debug use only: make better, more interesting UI effects and hooks for this
func crit_damage(damage: int) -> void:
	show_gun_status("CRIT! %s damage" % [damage], Color.RED)
	SoundManager.play_sound(TEMP_crit)


func show_gun_status(text: String, color: Color = Color.WHITE, duration: float = 0.4) -> void:
	gun_status_label.modulate = color
	gun_status_label.text = text
	
	gun_status_label.visible = true
	gun_status_label.modulate = Color(color, 0)
	
	var tween = get_tree().create_tween()
	tween.tween_property(gun_status_label, "modulate", Color(color, 1.0), 0.4)
	await get_tree().create_timer(duration).timeout
	#tween.tween_property(gun_status_label, "modulate:a", 0, 1.0)


func _on_jam_timer_timeout() -> void:
	is_jammed = false
	gun_status_label.visible = false


func get_spread_direction(center_direction: Vector3) -> Vector3:
	# Convert spread angle to radians
	var max_radians = deg_to_rad(modified_spread_angle)

	# Generate random rotation within the spread cone
	var random_yaw = randf_range(-max_radians, max_radians)
	var random_pitch = randf_range(-max_radians, max_radians)

	# Create a rotation basis
	var spread_rotation = Basis(Vector3.UP, random_yaw) * Basis(Vector3.RIGHT, random_pitch)

	# Apply the rotation to the center direction
	return (spread_rotation * center_direction).normalized()

func play_failed_shoot_sfx():
	if failed_shoot_sfx_timer.is_stopped():
		SoundManager.play_sound(TEMP_sfx_dry)
		failed_shoot_sfx_timer.start()
