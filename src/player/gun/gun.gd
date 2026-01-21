extends Node3D
class_name Gun

signal gun_shot
signal reload_anim_end
signal post_reload_anim_end
signal spin_anim_trigger
signal full_clip_reload_started
signal gun_reloaded

signal barrel_spin_started(barrel: SpinBarrel, barrel_idx: int)
signal barrel_spin_stopped(barrel: SpinBarrel, barrel_idx: int)
signal barrel_effect_set(barrel_idx: int, effect: BaseBarrelEffect)
signal barrel_equipped(barrel: SpinBarrel, barrel_idx: int)
signal barrel_unequipped(barrel: SpinBarrel, barrel_idx: int)

@export var gun_name: String
@export_multiline var description: String
@export var max_barrels: int = 3

## SPRITES
@export_group("Sprites")
var barrel_flare_sprite: Sprite3D
var muzzle_flash_sprite: Sprite3D
@export var muzzle_flash_hold_frames: int = 2
#
@export var shotgun_flare_sprite: Sprite3D
@export var shotgun_flash_sprite: Sprite3D
@export var shotgun_shell_particles: GPUParticles3D
@export var smg_flare_sprite: Sprite3D
@export var smg_flash_sprite: Sprite3D
@export var smg_shell_particles: GPUParticles3D
@export var rifle_flare_sprite: Sprite3D
@export var rifle_flash_sprite: Sprite3D
@export var rifle_shell_particles: GPUParticles3D

@onready var arm_sprite: Sprite3D = $SpriteParent/ArmSprite
@onready var barrel_1_sprite: Sprite3D = $SpriteParent/Barrel1Sprite
@onready var barrel_1_label: Label3D = $SpriteParent/Barrel1Sprite/Label3D
@onready var barrel_2_sprite: Sprite3D = $SpriteParent/Barrel2Sprite
@onready var barrel_2_label: Label3D = $SpriteParent/Barrel2Sprite/Label3D
@onready var barrel_3_sprite: Sprite3D = $SpriteParent/Barrel3Sprite
@onready var barrel_3_label: Label3D = $SpriteParent/Barrel3Sprite/Label3D
@onready var barrel_sprites: Array[Sprite3D] = [barrel_1_sprite, barrel_2_sprite, barrel_3_sprite]
@onready var barrel_labels: Array[Label3D] = [barrel_1_label, barrel_2_label, barrel_3_label]
@onready var barrel_icon_mesh_1: MeshInstance3D = $EffectIconsViewport/EffectIconsParent/Barrel1Icon
@onready var barrel_icon_mesh_2: MeshInstance3D = $EffectIconsViewport/EffectIconsParent/Barrel2Icon
@onready var barrel_icon_mesh_3: MeshInstance3D = $EffectIconsViewport/EffectIconsParent/Barrel3Icon
@onready var barrel_icon_meshes: Array[MeshInstance3D] = [barrel_icon_mesh_1, barrel_icon_mesh_2, barrel_icon_mesh_3]
@onready var default_barrel_icon_mat: StandardMaterial3D = load("res://src/player/gun/assets/material/default_effect_icon_mat.tres")

@onready var anim_tree: AnimationTree = $AnimationTree
#
@onready var idle_frame_state = anim_tree.get("parameters/idle_frame_state/playback")
@onready var reload_frame_state = anim_tree.get("parameters/reload_frame_state/playback")

@export_group("SFX")
## TEMP SFX PLS CHANGE
@export var TEMP_sfx_shoot: AudioStream
@export var TEMP_sfx_dry: AudioStream
@export var TEMP_sfx_spin: AudioStream
@export var TEMP_sfx_reload: AudioStream
@export var TEMP_sfx_click: AudioStream
@export var TEMP_regain_ammo: AudioStream
@export var TEMP_crit: AudioStream

# Init gun stat values
const BASE_DAMAGE: int = 20
const BASE_PROJECTILE_AMOUNT: int = 1
const BASE_FIRERATE: float = 2.0
const BASE_MAGAZINE_SIZE: int = 10
const BASE_RELOAD_TIME: float = 1.0
const BASE_SPIN_TIME: float = 1.0
const BASE_SPREAD_ANGLE: float = 0.5
const IS_HITSCAN: bool = false
const BASE_PROJECTILE_SPEED: float = 50.0
const RECOIL_AMOUNT: float = 0.03
const SCREENSHAKE_AMOUNT: float = 0.2
const BASE_CUSTOM_PROJECTILE_PREFAB: PackedScene = null

var base_damage: int = BASE_DAMAGE
var base_projectile_amount: int = BASE_PROJECTILE_AMOUNT
## Shot per second
var base_firerate: float = BASE_FIRERATE
var base_magazine_size: int = BASE_MAGAZINE_SIZE
var base_reload_time: float = BASE_RELOAD_TIME
var base_spin_time: float = BASE_SPIN_TIME
## How spread out projectile can be from the aim center
var base_spread_angle: float = BASE_SPREAD_ANGLE
## Projectile dont have travel time. Shot enemy is instanly damaged. If this ticked, ignore projectile_speed
var is_hitscan: bool = IS_HITSCAN
## How fast projectile travel. Ignored if is_hitscan ticked. Shouldn't higher than 100 or collision detecion
## will be an issue
var base_projectile_speed: float = BASE_PROJECTILE_SPEED
var recoil_amount: float = RECOIL_AMOUNT
## How much screenshake when player shot
var screenshake_amount: float = SCREENSHAKE_AMOUNT
var base_custom_projectile_prefab: PackedScene = BASE_CUSTOM_PROJECTILE_PREFAB

@export_group("Prefab Scenes")
@export var hitscan_prefab: PackedScene
@export var projectile_prefab: PackedScene
@export var muzzle_smoke_prefab: PackedScene

@onready var barrel_container = $BarrelContainer
#@onready var gun_status_label: Label3D = $PlaceholderUI/StatusLabel
@onready var bullet_spawn_marker = $BulletStartPos
@onready var jam_timer: Timer = $JamTimer
@onready var failed_shoot_sfx_timer: Timer = $FailToShootSFXTimer
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var muzzle_flash_light: OmniLight3D = $BulletStartPos/MuzzleFlashLight
@onready var smoke_timer: Timer = $SmokeTimer

var magazine_ammo_left: int = 0
var cached_reload_start_ammo: int = magazine_ammo_left
var reload_interrupt: bool = false
var can_fire: bool = true
var is_reloading: bool = false
var is_reload_disabled: bool = false
var is_spinning: bool = false
var is_jammed: bool = false
var time_since_last_shot: float = 0.0

var installed_barrels: Array[SpinBarrel] = []
var barrel_count: int = 0

var is_trigger_pulled = false
var muzzle_light_tween: Tween
var reinstalled_barrel_from_savefile = false

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
var modified_spread_horizontal_bias = 0.5
var modified_reload_time
var modified_spin_time
var modified_ricochet_count = 0
var modified_homing_strength: float = 0 # radius to search for enemy
var modified_projectile_prefab: PackedScene = null
var projectile_prefab_can_be_pooled = false
var modified_recoil
var modified_screenshake

const MIN_DELAY_BETWEEN_SHOT_IN_BURST = 0.1
const BULLET_SPAWN_POS_VARIATION = 10
const TIME_BETWEEN_MUZZLE_SMOKE = 0.25

var current_reload_anim_time: float


func _ready() -> void:
	LoadingHandler.loaded_seamless.connect(equip_active)
	ScreenTransition.transition_midpoint.connect(equip_active)
	SaveManager.savefile_loaded.connect(_on_savefile_loaded)
	barrel_equipped.connect(_on_archetype_equipped)
	barrel_unequipped.connect(_on_archetype_unequipped)
	
	reset_modifier(true)
	idle_frame_state.start("RESET")
	
	if SaveManager.save_data_is_loaded:
		_on_savefile_loaded()
	else:
		await reinstall_barrels()


func equip_active() -> void:
	#reset_modifier(true)
	if GameManager.equipped_gun_frame:
		set_stat_from_gun_frame()
	#magazine_ammo_left = modified_magazine_size
	muzzle_flash_light.light_energy = 0


func _process(delta: float) -> void:
	time_since_last_shot += delta
	# EXPERIMENTAL for hold/release spinning
	#if Input.is_action_just_released("spin_barrels"):
		#var state_machine = anim_tree.get("parameters/spin_state/playback")
		#state_machine.travel("released")


func set_frame_art(frame_id: int = GunFrameResource.GunFrameIdEnum.DEFAULT, skip_animation: bool = false) -> void:
	# DEBUG: 
	# enum GunFrameIdEnum {
	#	NONE,
	#	DEFAULT,
	#	SHOTGUN,
	#	SMG,
	#	SNIPER
	#}
	var flare_sprites = [null, null, shotgun_flare_sprite, smg_flare_sprite, rifle_flare_sprite]
	var flash_sprites = [null, null, shotgun_flash_sprite, smg_flash_sprite, rifle_flash_sprite]
	barrel_flare_sprite = flare_sprites[frame_id]
	muzzle_flash_sprite = flash_sprites[frame_id]
	
	var frame_prefixes = ["", "", "shotgun_idle", "smg_idle", "rifle_idle"]
	var idle_state = frame_prefixes[frame_id]
	
	if skip_animation:
		idle_frame_state.start(idle_state)
	else:
		idle_frame_state.travel(idle_state)


func set_stat_from_gun_frame() -> void:
	var current_frame: GunFrameResource = GameManager.equipped_gun_frame
	if current_frame.frame_id == GunFrameResource.GunFrameIdEnum.NONE:
		return
	
	base_damage = current_frame.base_damage
	base_projectile_amount = current_frame.base_projectile_amount
	base_firerate = current_frame.base_firerate
	base_magazine_size = current_frame.base_magazine_size
	base_reload_time = current_frame.base_reload_time
	base_spin_time = current_frame.base_spin_time
	base_spread_angle = current_frame.base_spread_angle
	is_hitscan = current_frame.is_hitscan
	base_projectile_speed = current_frame.base_projectile_speed
	recoil_amount = current_frame.recoil_amount
	screenshake_amount = current_frame.screenshake_amount
	base_custom_projectile_prefab = current_frame.base_custom_projectile_prefab
	#
	cancel_reload()
	reset_modifier(true)
	for barrel in barrel_container.get_children():
		barrel.get_active_effect().on_effect_set()
	reload_no_anim()
	set_frame_art(current_frame.frame_id)
	
	if current_frame.frame_id != GunFrameResource.GunFrameIdEnum.NONE:
		if LoadingHandler.skip_equip_anim:
			play_equip_anim(current_frame.frame_id)
			# FIXME - this anim doesn't work for some reason
			#play_active_anim(current_frame.frame_id)
		else:
			play_equip_anim(current_frame.frame_id)
	
	LoadingHandler.skip_equip_anim = false


func clear_gun_stats() -> void:
	base_damage = BASE_DAMAGE
	base_projectile_amount = BASE_PROJECTILE_AMOUNT
	base_firerate = BASE_FIRERATE
	base_magazine_size = BASE_MAGAZINE_SIZE
	base_reload_time = BASE_RELOAD_TIME
	base_spin_time = BASE_SPIN_TIME
	base_spread_angle = BASE_SPREAD_ANGLE
	is_hitscan = IS_HITSCAN
	base_projectile_speed = BASE_PROJECTILE_SPEED
	recoil_amount = RECOIL_AMOUNT
	screenshake_amount = SCREENSHAKE_AMOUNT
	base_custom_projectile_prefab = BASE_CUSTOM_PROJECTILE_PREFAB
	#
	cancel_reload()
	reload_no_anim()


## Return true if shot successful
func shoot(aim_ray: RayCast3D) -> bool:
	if not GameManager.equipped_gun_frame:
		return false
	if GameManager.equipped_gun_frame.frame_id == GunFrameResource.GunFrameIdEnum.NONE:
		return false
	
	if is_reloading or is_spinning or is_jammed:
		if is_reloading and \
		idle_frame_state.get_current_node().begins_with("shotgun") and \
		reload_interrupt == false:
			# When the player tries to shoot during a shotgun reload,
			# finish the current shell loading anim and interrupt the reload,
			# keeping the ammo count at whatever it is after the last shell.
			reload_interrupt = true
			idle_frame_state.travel("shotgun_idle")
			await reload_anim_end
			
			# Play the post-reload pump to chamber a round if we started reloading from empty
			if cached_reload_start_ammo == 0:
				idle_frame_state.travel("shotgun_pump_no_shell")
				await post_reload_anim_end
		else:
			play_failed_shoot_sfx()
			return false
	
	reload_interrupt = false
	
	if magazine_ammo_left <= 0:
		play_failed_shoot_sfx()
		if not is_reload_disabled:
			reload()
		return false
	
	for barrel in installed_barrels:
		can_fire = can_fire and barrel.get_active_effect().on_fire_attempt()
	if not can_fire:
		play_failed_shoot_sfx()
		return false
	
	for barrel in installed_barrels:
		barrel.get_active_effect().on_fire_rate_check()
	
	var time_until_next_shot = 1.0 / modified_firerate
	if time_until_next_shot > time_since_last_shot:
		return false
	
	for barrel in installed_barrels:
		barrel.get_active_effect().on_prepare_to_fire()
	
	can_fire = false
	
	GameManager.player.player_camera.set_recoil_power(modified_recoil)
	GameManager.player.player_camera.add_trauma(modified_screenshake)

	for barrel in installed_barrels:
		barrel.get_active_effect().on_gun_damage_calculation()

	for i in range(n_shot_repeat):
		if len(GameManager.equipped_gun_frame.shot_sfx) > 0:
			SoundManager.play_sound_with_pitch(GameManager.equipped_gun_frame.shot_sfx.pick_random(), randf_range(0.85, 1.15), "Gun")
		else:
			SoundManager.play_sound_with_pitch(TEMP_sfx_shoot, randf_range(0.85, 1.15), "Gun")

		var bullet_start_pos = bullet_spawn_marker.global_position

		for j in range(modified_projectile_amount):
			var aim_direction = aim_ray.aim_ray_end.global_position - bullet_spawn_marker.global_position
			var spread_direction = GunUtils.get_spread_direction(aim_direction, modified_spread_angle, modified_spread_horizontal_bias)
			if modified_projectile_prefab:
				create_gun_attack(modified_projectile_prefab, bullet_start_pos, spread_direction, modified_damage, modified_projectile_speed)
			elif modified_is_hitscan:
				create_gun_attack(hitscan_prefab, bullet_start_pos, spread_direction, modified_damage, modified_projectile_speed)
			else:
				create_gun_attack(projectile_prefab, bullet_start_pos, spread_direction, modified_damage, modified_projectile_speed)

		time_since_last_shot = 0
		GameManager.player.player_camera.recoil_fire()

		magazine_ammo_left -= n_ammo_consume
		for barrel in installed_barrels:
			barrel.get_active_effect().on_ammo_consumed()
		if magazine_ammo_left <= 0 and i < n_shot_repeat - 1:
			break
		
		var test0 = idle_frame_state.get_current_node()
		if idle_frame_state.get_current_node().begins_with("smg"):
			smg_shell_particles.emitting = true
			smg_shell_particles.restart()
		
		gun_shot.emit()
		
		if n_shot_repeat > 1 and i < n_shot_repeat - 1:
			barrel_flare_sprite.visible = true
			await get_tree().create_timer(MIN_DELAY_BETWEEN_SHOT_IN_BURST).timeout
			barrel_flare_sprite.visible = false
		else:
			barrel_flare_sprite.visible = true
			for j in range(muzzle_flash_hold_frames):
				await get_tree().physics_frame
			barrel_flare_sprite.visible = false
	
	# Create muzzle smoke effect
	create_muzzle_smoke(aim_ray)
	create_muzzle_flash_light()
	
	## POST-SHOT animations
	await play_post_shot_anim()
	
	reset_modifier()
	can_fire = true
	
	return true


func _play_anim_cancel(
	anim_suffix: String, 
	frame_id: int = GameManager.equipped_gun_frame.frame_id,
	callback: Callable = Callable(),
) -> void:
	cancel_reload()
	stop_all_barrels(0.0)
	var anim_state: String = ""
	match frame_id:
		GunFrameResource.GunFrameIdEnum.SHOTGUN:
			anim_state += "shotgun"
		GunFrameResource.GunFrameIdEnum.SMG:
			anim_state += "smg"
		GunFrameResource.GunFrameIdEnum.SNIPER:
			anim_state += "rifle"
	anim_state += "_" + anim_suffix
	
	# Teleport to the equip anim state
	idle_frame_state.start(anim_state)
	
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	if callback:
		callback.call()

func play_active_anim(frame_id: int = GameManager.equipped_gun_frame.frame_id) -> void:
	_play_anim_cancel("active", frame_id, spin_all_barrels)


func play_equip_anim(frame_id: int = GameManager.equipped_gun_frame.frame_id) -> void:
	_play_anim_cancel("equip", frame_id, spin_all_barrels)


func play_unequip_anim(frame_id: int = GameManager.equipped_gun_frame.frame_id) -> void:
	_play_anim_cancel("unequip", frame_id)


func play_post_shot_anim() -> bool:
	var post_shot_state: String
	var idle_state: String = idle_frame_state.get_current_node()
	match idle_state:
		"shotgun_idle":
			post_shot_state = "shotgun_pump"
		"smg_idle":
			pass
		"rifle_idle":
			post_shot_state = "rifle_rack"
	
	anim_tree.set("parameters/reload_timescale/scale", 1.0)
	#var reload_timescale: float = 1.35 / modified_reload_time
	#anim_tree.set("parameters/reload_timescale/scale", reload_timescale) # FIXME: Need to do sth with base_reload_time here
	
	if post_shot_state: 
		idle_frame_state.travel(post_shot_state)
		await post_reload_anim_end
		
	#anim_tree.set("parameters/reload_timescale/scale", 1.0)
	
	if magazine_ammo_left <= 0:
		reload()
	
	idle_frame_state.travel(idle_state)
	
	return true


func create_gun_attack(bullet_prefab: PackedScene, start_pos: Vector3, direction: Vector3, damage: int, proj_speed, max_range: float = 500):
	var bullet_inst: BaseBullet = null
	if projectile_prefab_can_be_pooled:
		bullet_inst = GameManager.object_pooling_manager.get_pooled_object(ObjectPoolingManager.PooledObjectEnum.GEL_STREAM_PROJECTILE)
		bullet_inst.activate(start_pos, direction)
	else:
		bullet_inst = bullet_prefab.instantiate()
		get_tree().get_root().add_child(bullet_inst)
	
	bullet_inst.owner_gun = self
	bullet_inst.homing_strength = modified_homing_strength

	if not bullet_inst.is_connected("before_damage_applied", check_barrel_effect_on_before_damage_applied):
		bullet_inst.before_damage_applied.connect(check_barrel_effect_on_before_damage_applied)

	if not bullet_inst.is_connected("damage_applied", check_barrel_effect_on_damage_applied):
		bullet_inst.damage_applied.connect(check_barrel_effect_on_damage_applied)

	if not bullet_inst.is_connected("impacted", check_barrel_effect_on_projectile_impact):
		bullet_inst.impacted.connect(check_barrel_effect_on_projectile_impact)

	if not bullet_inst.is_connected("destroyed", check_barrel_effect_on_projectile_destroyed):
		bullet_inst.destroyed.connect(check_barrel_effect_on_projectile_destroyed)

	for barrel in installed_barrels:
		barrel.get_active_effect().on_projectile_spawn(bullet_inst)

	bullet_inst.init(start_pos, direction, damage, modified_ricochet_count, proj_speed, max_range)

func check_barrel_effect_on_before_damage_applied(_enemy: CharacterBody3D, _projectile: BaseBullet):
	for barrel in installed_barrels:
		barrel.get_active_effect().on_before_damage_applied(_enemy, _projectile)

func check_barrel_effect_on_damage_applied(_damage: float, _has_pos: bool = false, _pos: Vector3 = Vector3.ZERO):
	for barrel in installed_barrels:
		barrel.get_active_effect().on_damage_applied(_damage, _has_pos, _pos)
	LuckHandler.accumulate_dps_dealt(_damage)

func check_barrel_effect_on_projectile_impact(_projectile: BaseBullet, _has_pos: bool = false, _pos: Vector3 = Vector3.ZERO):
	for barrel in installed_barrels:
		barrel.get_active_effect().on_projectile_impact(_projectile, _has_pos, _pos)

func check_barrel_effect_on_projectile_destroyed(hit_boss: bool):
	for barrel in installed_barrels:
		barrel.get_active_effect().on_projectile_destroyed(hit_boss)

func check_barrel_effect_on_dash_movement():
	for barrel in installed_barrels:
		barrel.get_active_effect().on_dash_movement()

func check_barrel_effect_on_player_damaged():
	for barrel in installed_barrels:
		barrel.get_active_effect().on_player_damaged()

func pull_trigger():
	if is_reloading or is_spinning:
		return
	if not is_trigger_pulled:
		is_trigger_pulled = true
		for barrel in installed_barrels:
			barrel.get_active_effect().on_trigger_pulled()

func release_trigger():
	if is_trigger_pulled:
		is_trigger_pulled = false
		for barrel in installed_barrels:
			barrel.get_active_effect().on_trigger_released()


func spin_all_barrels() -> void:
	if is_reloading:
		await gun_reloaded
	
	var barrels_to_spin: int = installed_barrels.size()
	if barrels_to_spin == 0:
		#reload()
		return

	release_trigger()
	
	is_spinning = true

	# EXPERIMENTAL for hold/release spinning
	#var state_machine = anim_tree.get("parameters/spin_state/playback")
	#state_machine.travel("pressed")

	anim_tree.set("parameters/spin_shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	await spin_anim_trigger

	# TODO - add catch for HELD barrels
	await get_tree().physics_frame
	barrels_to_spin = installed_barrels.size()  # Check again to prevent bug
	for i in barrels_to_spin:
		if i > barrels_to_spin:
			break
		# Optional delay between each barrel spinning
		#await get_tree().create_timer(0.05).timeout
		_spin_barrel(i)

	# TODO - replace with a dedicated spin time value now reloading isn't directly
	# tied to spinning
	await get_tree().create_timer(base_spin_time).timeout

	#reset_modifier(true)
	#gun_status_label.visible = false
	stop_all_barrels()

	#reload(true)


func _spin_barrel(barrel_idx: int) -> void:
	var barrel = installed_barrels[barrel_idx]
	barrel.get_active_effect().on_barrel_start_spin()
	barrel.start_spin()
	# TODO - tidy this up and make the setting/resetting of the reload label generic
	var barrel_label: Label3D = barrel_labels[barrel_idx]
	barrel_label.text = "[%s]" % [
		barrel.reloads_before_spin - barrel.reload_count
	]
	barrel.reload_count = 0
	var state_machine = anim_tree.get("parameters/barrel_%s_state/playback" % [(barrel_idx + 1)])
	# Spin the effect mesh UV
	# TODO 
	# If we don't have an effect equipped,
	# travel straight to the spin anim without the decal start anim
	state_machine.travel("spin_start")
	#state_machine.travel("spin")
	SoundManager.play_sound(TEMP_sfx_spin, "Gun")
	barrel_spin_started.emit(barrel, barrel_idx)


func stop_all_barrels(delay_offset: float = 0.1) -> void:
	reset_modifier(true)
	for i in installed_barrels.size():
		_stop_barrel(i)
		await get_tree().create_timer(delay_offset).timeout
	is_spinning = false
	can_fire = true


func _stop_barrel(barrel_idx: int) -> void:
	var barrel = installed_barrels[barrel_idx]
	if not barrel:
		return
	barrel.stop_spin()
	# Update barrel icon
	set_barrel_icon(barrel_idx, barrel.get_active_effect().icon_id)
	barrel.get_active_effect().on_barrel_stop_spin()
	var state_machine = anim_tree.get("parameters/barrel_%s_state/playback" % [(barrel_idx + 1)])
	state_machine.travel("idle")
	
	SoundManager.stop_sound(TEMP_sfx_spin)
	barrel.get_active_effect().on_effect_set()
	magazine_ammo_left = clamp(magazine_ammo_left, 0, modified_magazine_size)
	barrel_spin_stopped.emit(barrel, barrel_idx)
	
	var barrel_label: Label3D = barrel_labels[barrel_idx]
	barrel_label.text = "[%s]" % [
		barrel.reloads_before_spin - barrel.reload_count
	]


func set_barrel_icon(barrel_idx: int, icon_id: int) -> void:
	var barrel_mesh: MeshInstance3D = barrel_icon_meshes[barrel_idx]
	
	var mat: StandardMaterial3D = barrel_mesh.get_surface_override_material(0)
	if mat == null:
		mat = default_barrel_icon_mat
	var new_mat: StandardMaterial3D = mat.duplicate()
	
	var icon_sprite_path := "res://assets/sprite/effect_icons/%s.png" % [icon_id]
	var icon_texture: CompressedTexture2D = load(icon_sprite_path)
	
	new_mat.albedo_color = Color.WHITE
	new_mat.albedo_texture = icon_texture
	barrel_mesh.set_surface_override_material(0, new_mat)


func cancel_reload() -> void:
	is_reloading = false
	is_jammed = false
	
	match idle_frame_state.get_current_node():
		"shotgun_reload":
			idle_frame_state.travel("shotgun_idle")
		"smg_reload":
			idle_frame_state.travel("smg_idle")
		"rifle_reload":
			idle_frame_state.travel("rifle_idle")


func reload(already_spin_barrel = false):
	# TODO - make this more generic and less tied to spinning barrels so we can call it elsewhere
	if is_reload_disabled:
		return
	if is_reloading:
		return
	if is_jammed:
		play_failed_shoot_sfx()
		return

	release_trigger()

	#if not already_spin_barrel:
		#reset_modifier(true)
	
	for barrel in installed_barrels:
		barrel.get_active_effect().on_reload_start()

	is_reloading = true
	
	cached_reload_start_ammo = magazine_ammo_left
	var reload_timescale: float = 1.5 / modified_reload_time
	var reload_state: String = ""
	var reload_anim: String = "reload"
	var post_reload_state: String = ""
	var post_reload_anim: String = ""
	var reload_count: int = 1  # Used to reload per-shot in the case of the shotgun
	
	var idle_state: String = idle_frame_state.get_current_node()
	if not idle_state.ends_with("idle"):
		await post_reload_anim_end
		idle_state = idle_frame_state.get_current_node()
		
	var anim_library_prefix: String = ""
	match idle_state:
	#match GameManager.equipped_gun_frame.frame_id:
		#GunFrameResource.GunFrameIdEnum.SHOTGUN:
		"shotgun_idle":
			anim_library_prefix = "shotgun/"
			reload_state = "shotgun_reload"
			if cached_reload_start_ammo == 0:
				post_reload_state = "shotgun_pump_no_shell"
				post_reload_anim = "pump_no_shell"
			#if cached_reload_start_ammo == modified_magazine_size:
				#post_reload_state = ""  # "shotgun_pump" - do we want to pump after reload? 
			#else:
				#post_reload_state = "" # "shotgun_pump_no_shell" - do we want to pump after reload? 
			reload_count = modified_magazine_size - magazine_ammo_left
			reload_timescale * 2.0
		#GunFrameResource.GunFrameIdEnum.SMG:
		"smg_idle":
			anim_library_prefix = "smg/"
			reload_state = "smg_reload"
		#GunFrameResource.GunFrameIdEnum.SNIPER:
		"rifle_idle":
			anim_library_prefix = "rifle/"
			reload_state = "rifle_reload"
			post_reload_state = "rifle_rack"
			post_reload_anim = "rack"
	
	anim_tree.set("parameters/reload_timescale/scale", reload_timescale) # FIXME: Need to do sth with base_reload_time here
	
	var reload_anim_time: float = anim_player.get_animation(anim_library_prefix + reload_anim).length
	var post_reload_anim_time: float = 0.0
	if post_reload_anim:
		post_reload_anim_time = anim_player.get_animation(anim_library_prefix + post_reload_anim).length
	
	current_reload_anim_time = (reload_anim_time * reload_timescale) + post_reload_anim_time
	
	if idle_state in ["smg_idle", "rifle_idle"]:
		full_clip_reload_started.emit()
	
	for i in range(reload_count):
		if reload_interrupt:
			break
		idle_frame_state.start(reload_state)
		# If we're loading ammo one at a time, tick the ammo count up
		match reload_count:
			1:
				magazine_ammo_left = modified_magazine_size
			_:
				magazine_ammo_left = cached_reload_start_ammo + i + 1
		await reload_anim_end
	
	if post_reload_state:
		idle_frame_state.travel(post_reload_state)
		await post_reload_anim_end
	
	reload_interrupt = false
	is_reloading = false
	can_fire = true
	anim_tree.set("parameters/reload_timescale/scale", 1.0)
	
	for barrel in installed_barrels:
		barrel.get_active_effect().on_reload_end()
	
	match GameManager.CHEAT_spin_mode:
		GameManager.DebugSpinMode.SEEDED_AUTO_SPIN:
			var barrels_to_auto_spin := []
			for i in range(barrel_container.get_child_count()):
				var barrel = barrel_container.get_child(i)
				barrel.reload_count += 1
				var barrel_label: Label3D = barrel_labels[i]
				barrel_label.text = "[%s]" % [
					barrel.reloads_before_spin -barrel.reload_count
				]
				if barrel.reload_count == barrel.reloads_before_spin:
					barrels_to_auto_spin.append(barrel)
			
			# Decrease luck for each barrel triggering auto-spin
			LuckHandler.decrease_luck(
				LuckHandler.luck_cost_per_auto_spin * len(barrels_to_auto_spin)
			)
			
			if len(barrels_to_auto_spin) == len(installed_barrels):
				spin_all_barrels()
			else:
				for _barrel in barrels_to_auto_spin:
					var i = barrel_container.get_children().find(_barrel)
					if i == -1:
						continue
					_spin_barrel(i)
					get_tree().create_timer(base_spin_time).timeout.connect(
						func(): 
							_stop_barrel(i)
							can_fire = true
					)
		GameManager.DebugSpinMode.ON_RELOAD:
			spin_all_barrels()


func reload_no_anim() -> void:
	#reset_modifier(true)
	
	for barrel in installed_barrels:
		if is_instance_valid(barrel):
			barrel.get_active_effect().on_reload_end()
	
	magazine_ammo_left = modified_magazine_size
	is_reloading = false
	reload_anim_end.emit()
	post_reload_anim_end.emit()
	gun_reloaded.emit()


func _shotgun_eject_shell() -> void:
	# TODO - pool/instance individual particle emitters per-shell so we 
	# can have them bouncing around? Then create a decal on particle end.
	pass


func _end_reload_anim() -> void:
	reload_anim_end.emit()


func _end_post_reload_anim() -> void:
	post_reload_anim_end.emit()


func _emit_reloaded_signal() -> void:
	gun_reloaded.emit()


func _trigger_spin_anim() -> void:
	spin_anim_trigger.emit()


func reset_modifier(reload_reset = false):
	n_ammo_consume = 1
	n_shot_repeat = 1
	modified_damage = base_damage
	modified_projectile_amount = base_projectile_amount
	modified_firerate = base_firerate
	modified_projectile_speed = base_projectile_speed
	modified_is_hitscan = is_hitscan
	modified_spread_angle = base_spread_angle
	modified_spread_horizontal_bias = 0.5
	modified_ricochet_count = 0
	modified_homing_strength = 0
	modified_recoil = recoil_amount
	modified_screenshake = screenshake_amount
	if reload_reset:
		modified_reload_time = base_reload_time
		modified_magazine_size = base_magazine_size
		modified_projectile_prefab = base_custom_projectile_prefab
		projectile_prefab_can_be_pooled = false


func jam_the_gun(duration: float = 1.0):
	#show_gun_status("Jammed...", Color.DIM_GRAY, duration)
	jam_timer.start(duration)
	is_jammed = true


# TODO - debug use only: make better, more interesting UI effects and hooks for this
func regain_ammo(_ammo: int) -> void:
	#show_gun_status("Regained +%s ammo" % [ammo], Color.CYAN)
	SoundManager.play_sound(TEMP_regain_ammo, "Gun")


# TODO - debug use only: make better, more interesting UI effects and hooks for this
func crit_damage(_damage: int) -> void:
	#show_gun_status("CRIT! %s damage" % [damage], Color.RED)
	SoundManager.play_sound(TEMP_crit, "Gun")


#func show_gun_status(text: String, color: Color = Color.WHITE, duration: float = 0.4) -> void:
	#gun_status_label.modulate = color
	#gun_status_label.text = text
#
	#gun_status_label.visible = true
	#gun_status_label.modulate = Color(color, 0)
#
	#var tween = get_tree().create_tween()
	#tween.tween_property(gun_status_label, "modulate", Color(color, 1.0), 0.4)
	#await get_tree().create_timer(duration).timeout
	##tween.tween_property(gun_status_label, "modulate:a", 0, 1.0)


func _on_jam_timer_timeout() -> void:
	is_jammed = false
	#gun_status_label.visible = false


func play_failed_shoot_sfx():
	if failed_shoot_sfx_timer.is_stopped():
		SoundManager.play_sound(TEMP_sfx_dry, "Gun")
		failed_shoot_sfx_timer.start()


func install_barrel(barrel_data: BarrelDataResource) -> void:
	if len(installed_barrels) >= max_barrels:
		return
	
	var barrel_inst = barrel_data.barrel_prefab.instantiate()
	#barrel_inst.barrel_effect_changed.connect(_set_barrel_effect_label)
	barrel_inst.barrel_effect_changed.connect(_on_barrel_effect_changed)
	barrel_container.add_child(barrel_inst)
	#_set_barrel_effect_label(barrel_inst, barrel_inst.get_active_effect())

	magazine_ammo_left = 0

	barrel_count = barrel_container.get_child_count()
	var barrel_idx: int = barrel_count - 1 if barrel_count > 0 else 0

	barrel_inst.owner_gun = self
	barrel_inst.reloads_before_spin = barrel_data.reloads_before_spin
	installed_barrels.append(barrel_inst)
	barrel_count = installed_barrels.size()

	barrel_inst.get_active_effect().on_barrel_install()
	set_barrel_icon(barrel_idx, barrel_inst.get_active_effect().icon_id)
	barrel_equipped.emit(barrel_inst, barrel_idx)

	recheck_installed_barrels()
	
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	# Re-apply the effects of the currently equipped barrels
	reset_modifier(true)
	for barrel in barrel_container.get_children():
		barrel.get_active_effect().on_effect_set()
	
	reload_no_anim()


func _on_barrel_effect_changed(barrel: SpinBarrel, effect: BaseBarrelEffect) -> void:
	barrel_effect_set.emit(barrel, effect)
	# Update the gun frame if we're using the archetype barrel
	match effect.icon_id:
		0:  # Rifle
			set_frame_art(GunFrameResource.GunFrameIdEnum.SNIPER, true)
		1:  # Shotgun
			set_frame_art(GunFrameResource.GunFrameIdEnum.SHOTGUN, true)
		2:  # SMG
			set_frame_art(GunFrameResource.GunFrameIdEnum.SMG, true)


func remove_barrel(barrel_idx: int) -> void:
	if len(installed_barrels) == 0:
		return

	var barrel: SpinBarrel = barrel_container.get_child(barrel_idx)
	barrel_container.remove_child(barrel)
	barrel.get_active_effect().on_barrel_remove()
	barrel_unequipped.emit(barrel, barrel_idx)
	barrel.queue_free()
	
	barrel_icon_meshes[barrel_idx].set_surface_override_material(0, default_barrel_icon_mat)
	
	recheck_installed_barrels()
	
	# Re-apply the effects of the currently equipped barrels
	reset_modifier(true)
	for _barrel in barrel_container.get_children():
		_barrel.get_active_effect().on_effect_set()


func recheck_installed_barrels():
	# Wait to make sure barrel actually instantiated or queue_freed
	await get_tree().process_frame
	await get_tree().process_frame
	installed_barrels.clear()
	for i in range(barrel_container.get_child_count()):
		var barrel = barrel_container.get_child(i)
		barrel.owner_gun = self
		installed_barrels.append(barrel)
		#_set_barrel_effect_label(barrel, barrel.get_active_effect())
		var barrel_label: Label3D = barrel_labels[i]
		barrel_label.text = "[%s]" % [
			barrel.reloads_before_spin -barrel.reload_count
		]
	
	barrel_count = installed_barrels.size()

	for i in barrel_sprites.size():
		var barrel_label: Label3D = barrel_labels[i]
		var state_machine = anim_tree.get("parameters/barrel_%s_state/playback" % [(i + 1)])
		if i < barrel_count:
			state_machine.travel("idle")
			barrel_icon_meshes[i].visible = true
			if GameManager.CHEAT_spin_mode == GameManager.DebugSpinMode.SEEDED_AUTO_SPIN:
				barrel_label.visible = true
			else:
				barrel_label.visible = false
		else:
			state_machine.travel("unequip")
			barrel_icon_meshes[i].visible = false
			barrel_icon_meshes[i].set_surface_override_material(0, default_barrel_icon_mat)
			barrel_label.visible = false


func reinstall_barrels():
	# Clear old barrels
	var equipped_barrel_count: int = barrel_container.get_child_count()
	for i in range(max_barrels):
		if i < equipped_barrel_count:
			var barrel = barrel_container.get_child(i)
			barrel.queue_free()
		barrel_unequipped.emit(null, i)

	# Instantiate barrels onto gun
	for i in GameManager.equipped_barrels.size():
		var barrel = GameManager.equipped_barrels[i]
		install_barrel(barrel)


func _set_barrel_effect_label(barrel: SpinBarrel, effect: BaseBarrelEffect) -> void:
	var label: Label3D
	var idx = barrel_container.get_children().find(barrel)
	match idx:
		0:
			label = barrel_1_label
		1:
			label = barrel_2_label
		2:
			label = barrel_3_label
		_:
			return
	label.text = effect.display_text_title


func _play_reload_start_sfx() -> void:
	if len(GameManager.equipped_gun_frame.reload_sfx) > 0:
		SoundManager.play_sound(GameManager.equipped_gun_frame.reload_sfx, "Gun")
	else:
		SoundManager.play_sound(TEMP_sfx_reload, "Gun")

func _play_reload_end_sfx() -> void:
	SoundManager.play_sound(TEMP_sfx_click, "Gun")


func create_muzzle_smoke(aim_ray: RayCast3D):
	if muzzle_smoke_prefab == null:
		return
	if not smoke_timer.is_stopped():
		return
	smoke_timer.start(TIME_BETWEEN_MUZZLE_SMOKE)
	var smoke_inst = muzzle_smoke_prefab.instantiate()
	get_tree().get_root().add_child(smoke_inst)
	var smoke_direction = aim_ray.aim_ray_end.global_position - bullet_spawn_marker.global_position
	smoke_inst.global_position = bullet_spawn_marker.global_position
	smoke_inst.look_at(smoke_inst.global_position + smoke_direction)


func create_muzzle_flash_light():
	muzzle_flash_light.light_energy = 3
	if muzzle_light_tween and muzzle_light_tween.is_running():
		muzzle_light_tween.stop()
	muzzle_light_tween = create_tween()
	muzzle_light_tween.tween_property(muzzle_flash_light, "light_energy", 0, 0.2).set_trans(Tween.TRANS_SINE)


func _on_savefile_loaded():
	if not reinstalled_barrel_from_savefile:
		reinstalled_barrel_from_savefile = true
		await reinstall_barrels()


func check_if_archetype_barrel_installed() -> bool:
	for barrel in GameManager.equipped_barrels:
		if barrel.is_archetype_barrel:
			return true
	return false


func _on_archetype_equipped(barrel: SpinBarrel, _barrel_idx: int) -> void:
	if barrel:
		if barrel.get_active_effect().is_archetype:
			clear_gun_stats()


func _on_archetype_unequipped(barrel: SpinBarrel, _barrel_idx: int) -> void:
	if barrel:
		if barrel.get_active_effect().is_archetype:
			set_stat_from_gun_frame()


func _debug_anim_tree_state_trace(state_name: String, transition: String) -> void:
	print("Anim state: %s - %s" % [state_name, transition])
