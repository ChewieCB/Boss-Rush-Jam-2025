extends Node3D
class_name Gun

@export var gun_name: String
@export_multiline var description: String


## SPRITES
@onready var gun_sprite: Sprite3D = $GunSprite
@export_group("Sprites")
@export_subgroup("0 Barrels")
@export var idle_0_barrel: Texture
@export_subgroup("1 Barrel")
@export var idle_1_barrel: Texture
@export var reload_frame_0_1_barrel: Texture
@export var reload_frame_1_1_barrel: Texture
@export_subgroup("2 Barrels")
@export var idle_2_barrel: Texture
@export var reload_frame_0_2_barrel: Texture
@export var reload_frame_1_2_barrel: Texture
@export_subgroup("3 Barrels")
@export var idle_3_barrel: Texture
@export var reload_frame_0_3_barrel: Texture
@export var reload_frame_1_3_barrel: Texture



## TEMP SFX PLS CHANGE
@export var TEMP_sfx_shoot: AudioStream
@export var TEMP_sfx_dry: AudioStream
@export var TEMP_sfx_reload: AudioStream
@export var TEMP_sfx_click: AudioStream
@export var TEMP_regain_ammo: AudioStream
@export var TEMP_crit: AudioStream

@export var max_barrels = 3
@export var base_damage = 20
@export var base_projectile_amount = 1
## Shot per second
@export var base_firerate = 2
@export var base_magazine_size = 10
@export var base_reload_time = 1
## How spread out projectile can be from the aim center
@export var base_spread_angle = 0.5
## Projectile dont have travel time. Shot enemy is instanly damaged. If this ticked, ignore projectile_speed
@export var is_hitscan: bool
## How fast projectile travel. Ignored if is_hitscan ticked. Shouldn't higher than 100 or collision detecion
## will be an issue
@export var base_projectile_speed: float = 50
@export var recoil_amount: float = 0.03
## How much screenshake when player shot
@export var screenshake_amount: float = 0.2

@export var aim_ray_prefab: PackedScene
@export var hitscan_prefab: PackedScene
@export var projectile_prefab: PackedScene

@onready var barrel_container = $Barrel
@onready var gun_status_label: Label3D = $PlaceholderUI/StatusLabel
@onready var bullet_spawn_marker = $BulletStartPos
@onready var jam_timer: Timer = $JamTimer
@onready var failed_shoot_sfx_timer: Timer = $FailToShootSFXTimer
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var magazine_ammo_left = 0
var is_reloading = false
var is_jammed = false
var time_since_last_shot = 0
var installed_barrels: Array[SpinBarrel] = []
var barrel_count: int = 0:
	set(value):
		barrel_count = value
		anim_player.play("%s_barrel_idle" % barrel_count)
		
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
var modified_ricochet_count = 0
var modified_homing_strength: float = 0 # radius to search for enemy
var modified_projectile_prefab: PackedScene = null
var modified_recoil
var modified_screenshake

signal gun_shot
signal gun_reloaded


const MIN_DELAY_BETWEEN_SHOT_IN_BURST = 0.1
const BULLET_SPAWN_POS_VARIATION = 10


func _ready() -> void:
	gun_status_label.visible = false
	magazine_ammo_left = base_magazine_size
	generate_gun_animations()
	reinstall_barrels()
	reset_modifier(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	reload()


func generate_gun_animations() -> void:
	for i in range(4):
		var idle_sprite: Texture
		var reload_sprites: Array
		match i:
			0:
				idle_sprite = idle_0_barrel
				reload_sprites = []
			1:
				idle_sprite = idle_1_barrel
				reload_sprites = [reload_frame_0_1_barrel, reload_frame_1_1_barrel]
			2:
				idle_sprite = idle_2_barrel
				reload_sprites = [reload_frame_0_2_barrel, reload_frame_1_2_barrel]
			3:
				idle_sprite = idle_3_barrel
				reload_sprites = [reload_frame_0_3_barrel, reload_frame_1_3_barrel]
		
		create_gun_anims(i, idle_sprite, reload_sprites)


func create_gun_anims(barrel_count: int, idle_texture: Texture, reload_textures: Array) -> void:
	var anim_root_node: Node = anim_player.get_node(anim_player.root_node)
	var gun_sprite_path: NodePath = anim_root_node.get_path_to(gun_sprite)
	var sprite_texture_path: NodePath = "%s:texture" % gun_sprite_path
	
	var base_library = anim_player.get_animation_library("")
	
	# Idle animation
	var idle_anim := Animation.new()
	idle_anim.step = 0.05
	idle_anim.length = 0.1
	idle_anim.loop = true
	
	var idle_texture_track_idx = idle_anim.add_track(Animation.TYPE_VALUE)
	idle_anim.track_set_path(idle_texture_track_idx, sprite_texture_path)
	idle_anim.track_insert_key(idle_texture_track_idx, 0.0, idle_texture)
	
	base_library.add_animation("%s_barrel_idle" % [barrel_count], idle_anim)
	
	# Reload animation
	if reload_textures == []:
		return
	var reload_anim := Animation.new()
	reload_anim.step = 0.05
	reload_anim.length = 0.1
	reload_anim.loop = true
	
	var reload_texture_track_idx = reload_anim.add_track(Animation.TYPE_VALUE)
	reload_anim.track_set_path(reload_texture_track_idx, sprite_texture_path)
	reload_anim.track_insert_key(reload_texture_track_idx, 0.0, reload_textures[0])
	reload_anim.track_insert_key(reload_texture_track_idx, 0.05, reload_textures[1])
	reload_anim.track_insert_key(reload_texture_track_idx, 0.1, reload_textures[0])
	
	base_library.add_animation("%s_barrel_reload" % [barrel_count], reload_anim)


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
	GameManager.player.player_camera.add_trauma(modified_screenshake)

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
			if modified_projectile_prefab:
				create_gun_attack(modified_projectile_prefab, bullet_start_pos, spread_direction, modified_damage, modified_projectile_speed)
			elif modified_is_hitscan:
				create_gun_attack(hitscan_prefab, bullet_start_pos, spread_direction, modified_damage, modified_projectile_speed)
			else:
				create_gun_attack(projectile_prefab, bullet_start_pos, spread_direction, modified_damage, modified_projectile_speed)

		time_since_last_shot = 0
		# Recoil
		GameManager.player.player_camera.rotate_x(modified_recoil)
		GameManager.player.player_camera.rotate_y(randf_range(-modified_recoil, modified_recoil))

		magazine_ammo_left -= n_ammo_consume
		for barrel in installed_barrels:
			barrel.get_active_effect().on_ammo_consumed()
		if magazine_ammo_left <= 0 and i < n_shot_repeat - 1:
			break

		gun_shot.emit()

		if n_shot_repeat > 1 and i < n_shot_repeat - 1:
			await get_tree().create_timer(MIN_DELAY_BETWEEN_SHOT_IN_BURST).timeout

	if magazine_ammo_left <= 0:
		for barrel in installed_barrels:
			barrel.get_active_effect().on_clip_empty()


func create_gun_attack(bullet_prefab: PackedScene, start_pos: Vector3, direction: Vector3, damage: int, proj_speed, max_range: float = 500):
	var bullet_inst = bullet_prefab.instantiate()
	bullet_inst.owner_gun = self
	bullet_inst.homing_strength = modified_homing_strength
	GameManager.player.get_parent().add_child(bullet_inst)
	bullet_inst.damage_applied.connect(check_barrel_effect_on_damage_applied)
	bullet_inst.impacted.connect(check_barrel_effect_on_projectile_impact)
	bullet_inst.destroyed.connect(check_barrel_effect_on_projectile_destroyed)
	bullet_inst.init(start_pos, direction, damage, modified_ricochet_count, proj_speed, max_range)

# func create_projectile_attack(start_pos: Vector3, direction: Vector3, damage: int, speed: float):
#     var projectile_inst: GunProjectile = projectile_prefab.instantiate()
#     projectile_inst.owner_gun = self
#     projectile_inst.homing_strength = modified_homing_strength
#     GameManager.player.get_parent().add_child(projectile_inst)
#     projectile_inst.init(start_pos, direction, damage, modified_ricochet_count, speed)
#     projectile_inst.damage_applied.connect(check_barrel_effect_on_damage_applied)
#     projectile_inst.impacted.connect(check_barrel_effect_on_projectile_impact)
#     projectile_inst.destroyed.connect(check_barrel_effect_on_projectile_destroyed)

func check_barrel_effect_on_damage_applied():
	for barrel in installed_barrels:
		barrel.get_active_effect().on_damage_applied()

func check_barrel_effect_on_projectile_impact(_has_pos: bool = false, _pos: Vector3 = Vector3.ZERO):
	for barrel in installed_barrels:
		barrel.get_active_effect().on_projectile_impact(_has_pos, _pos)

func check_barrel_effect_on_projectile_destroyed():
	for barrel in installed_barrels:
		barrel.get_active_effect().on_projectile_destroyed()

func check_barrel_effect_on_dash_movement():
	for barrel in installed_barrels:
		barrel.get_active_effect().on_dash_movement()

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
	
	if barrel_count > 0:
		anim_player.play("%s_barrel_reload" % barrel_count)
	
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
	anim_player.play("%s_barrel_idle" % barrel_count)
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
	modified_ricochet_count = 0
	modified_homing_strength = 0
	modified_recoil = recoil_amount
	modified_screenshake = screenshake_amount
	if reload_reset:
		modified_reload_time = base_reload_time
		modified_magazine_size = base_magazine_size
		modified_projectile_prefab = null


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


func install_barrel(barrel_prefab: PackedScene):
	if len(installed_barrels) >= max_barrels:
		return
	var barrel_inst = barrel_prefab.instantiate()
	for child in barrel_container.get_children():
		if child.get_child_count() == 0:
			child.add_child(barrel_inst)
			# installed_barrels.append(barrel_inst)
			break
	magazine_ammo_left = 0
	# This is just to force magazein UI update
	gun_reloaded.emit()
	recheck_installed_barrels()

func remove_barrel(search_barrel_id: BarrelDataResource.BarrelIdEnum):
	for child in barrel_container.get_children():
		if child.get_child_count() > 0:
			var barrel: SpinBarrel = child.get_child(0)
			if barrel.barrel_id == search_barrel_id:
				# installed_barrels.erase(barrel)
				barrel.queue_free()
				break
	await get_tree().process_frame
	await get_tree().process_frame
	recheck_installed_barrels()

func recheck_installed_barrels():
	installed_barrels = []
	for child in barrel_container.get_children():
		if child.get_child_count() > 0:
			var barrel = child.get_child(0)
			barrel.owner_gun = self
			installed_barrels.append(barrel)
	
	barrel_count = installed_barrels.size()


## Use after change scene
func reinstall_barrels():
	for i in range(len(GameManager.equipped_barrels)):
		var barrel_inst: SpinBarrel = GameManager.equipped_barrels[i].barrel_prefab.instantiate()
		barrel_container.get_child(i).add_child(barrel_inst)
	await get_tree().process_frame
	await get_tree().process_frame
	recheck_installed_barrels()
