extends Node3D
class_name Gun

signal gun_shot
signal reload_anim_end
signal spin_anim_trigger
signal gun_reloaded

signal barrel_spin_started(barrel: SpinBarrel, barrel_idx: int)
signal barrel_spin_stopped(barrel: SpinBarrel, barrel_idx: int)
signal barrel_equipped(barrel: SpinBarrel, barrel_idx: int)
signal barrel_unequipped(barrel: SpinBarrel, barrel_idx: int)

@export var gun_name: String
@export_multiline var description: String

## SPRITES
@export_group("Sprites")
@onready var gun_sprite: Sprite3D = $SpriteParent/GunSprite
@onready var barrel_flare_sprite: Sprite3D = $SpriteParent/GunSprite/MuzzleflareLightSprite
@onready var muzzle_flash_sprite: Sprite3D = $SpriteParent/GunSprite/MuzzleflareLightSprite/MuzzleFlashSprite
@export var muzzle_flash_hold_frames: int = 2
@onready var foregrip_sprite: Sprite3D = $SpriteParent/ForegripSprite
@onready var arm_sprite: Sprite3D = $SpriteParent/ArmSprite
@onready var barrel_1_sprite: Sprite3D = $SpriteParent/Barrel1Sprite
@onready var barrel_1_label: Label3D = $SpriteParent/Barrel1Sprite/Label3D
@onready var barrel_2_sprite: Sprite3D = $SpriteParent/Barrel2Sprite
@onready var barrel_2_label: Label3D = $SpriteParent/Barrel2Sprite/Label3D
@onready var barrel_3_sprite: Sprite3D = $SpriteParent/Barrel3Sprite
@onready var barrel_3_label: Label3D = $SpriteParent/Barrel3Sprite/Label3D
@onready var barrel_sprites: Array[Sprite3D] = [barrel_1_sprite, barrel_2_sprite, barrel_3_sprite]
@onready var barrel_labels: Array[Label3D] = [barrel_1_label, barrel_2_label, barrel_3_label]

@onready var anim_tree: AnimationTree = $AnimationTree

@export_group("SFX")
## TEMP SFX PLS CHANGE
@export var TEMP_sfx_shoot: AudioStream
@export var TEMP_sfx_dry: AudioStream
@export var TEMP_sfx_spin: AudioStream
@export var TEMP_sfx_reload: AudioStream
@export var TEMP_sfx_click: AudioStream
@export var TEMP_regain_ammo: AudioStream
@export var TEMP_crit: AudioStream

@export_group("Gun Properties")
@export var max_barrels = 3
@export var base_damage = 20
@export var base_projectile_amount = 1
## Shot per second
@export var base_firerate = 2
@export var base_magazine_size = 10
@export var base_reload_time = 1
@export var base_spin_time = 1
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

var magazine_ammo_left = 0
var is_reloading = false
var is_jammed = false
var time_since_last_shot = 0
var installed_barrels: Array[SpinBarrel] = []
var barrel_count: int = 0
		
var is_trigger_pulled = false
var muzzle_light_tween: Tween

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
var modified_spin_time
var modified_ricochet_count = 0
var modified_homing_strength: float = 0 # radius to search for enemy
var modified_projectile_prefab: PackedScene = null
var modified_recoil
var modified_screenshake

const MIN_DELAY_BETWEEN_SHOT_IN_BURST = 0.1
const BULLET_SPAWN_POS_VARIATION = 10


func _ready() -> void:
	#SaveManager.savefile_loaded.connect(reinstall_barrels)
	magazine_ammo_left = base_magazine_size
	muzzle_flash_light.light_energy = 0
	await get_tree().physics_frame
	await get_tree().physics_frame
	reinstall_barrels()
	reset_modifier(true)
	reload()


func _process(delta: float) -> void:
	time_since_last_shot += delta
	# EXPERIMENTAL for hold/release spinning
	#if Input.is_action_just_released("spin_barrels"):
		#var state_machine = anim_tree.get("parameters/spin_state/playback")
		#state_machine.travel("released")


## Return true if shot successful
func shoot(aim_ray: RayCast3D) -> bool:
	if is_reloading or is_jammed:
		play_failed_shoot_sfx()
		return false
	if magazine_ammo_left <= 0:
		play_failed_shoot_sfx()
		reload()
		return false

	var time_until_next_shot = 1.0 / modified_firerate
	if time_until_next_shot > time_since_last_shot:
		return false

	#reset_modifier()

	var can_fire = true
	for barrel in installed_barrels:
		can_fire = can_fire and barrel.get_active_effect().on_fire_attempt()
	if not can_fire:
		play_failed_shoot_sfx()
		return false

	for barrel in installed_barrels:
		barrel.get_active_effect().on_fire_rate_check()

	for barrel in installed_barrels:
		barrel.get_active_effect().on_prepare_to_fire()

	if barrel_count == 0:
		SoundManager.play_sound(TEMP_sfx_shoot, "Gun")

	GameManager.player.player_camera.set_recoil_power(modified_recoil)
	GameManager.player.player_camera.add_trauma(modified_screenshake)

	for barrel in installed_barrels:
		barrel.get_active_effect().on_damage_calculation()

	for i in range(n_shot_repeat):
		var bullet_start_pos = bullet_spawn_marker.global_position

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
		# Recoil (old)
		# GameManager.player.player_camera.rotate_x(modified_recoil)
		# GameManager.player.player_camera.rotate_y(randf_range(- modified_recoil, modified_recoil))
		GameManager.player.player_camera.recoil_fire()

		magazine_ammo_left -= n_ammo_consume
		for barrel in installed_barrels:
			barrel.get_active_effect().on_ammo_consumed()
		if magazine_ammo_left <= 0 and i < n_shot_repeat - 1:
			break
		
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

	if magazine_ammo_left <= 0:
		for barrel in installed_barrels:
			barrel.get_active_effect().on_clip_empty()

	# Create muzzle smoke effect
	create_muzzle_smoke(aim_ray)
	create_muzzle_flash_light()

	return true


func create_gun_attack(bullet_prefab: PackedScene, start_pos: Vector3, direction: Vector3, damage: int, proj_speed, max_range: float = 500):
	var bullet_inst = bullet_prefab.instantiate()
	bullet_inst.owner_gun = self
	bullet_inst.homing_strength = modified_homing_strength
	GameManager.player.get_parent().add_child(bullet_inst)
	bullet_inst.damage_applied.connect(check_barrel_effect_on_damage_applied)
	bullet_inst.damage_applied.connect(LuckHandler.accumulate_dps_dealt.unbind(2))
	bullet_inst.impacted.connect(check_barrel_effect_on_projectile_impact)
	bullet_inst.destroyed.connect(check_barrel_effect_on_projectile_destroyed)
	bullet_inst.init(start_pos, direction, damage, modified_ricochet_count, proj_speed, max_range)

func check_barrel_effect_on_damage_applied(_damage: float, _has_pos: bool = false, _pos: Vector3 = Vector3.ZERO):
	for barrel in installed_barrels:
		barrel.get_active_effect().on_damage_applied(_has_pos, _pos)

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


func spin_all_barrels() -> void:
	var barrels_to_spin: int = installed_barrels.size()
	if barrels_to_spin == 0:
		return
	
	release_trigger()
	is_reloading = true
	
	# EXPERIMENTAL for hold/release spinning
	#var state_machine = anim_tree.get("parameters/spin_state/playback")
	#state_machine.travel("pressed")
	
	anim_tree.set("parameters/spin_shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	await spin_anim_trigger
	
	# TODO - add catch for HELD barrels
	for i in barrels_to_spin:
		if i > barrels_to_spin:
			break
		_spin_barrel(i)
	
	# TODO - replace with a dedicated spin time value now reloading isn't directly
	# tied to spinning
	await get_tree().create_timer(base_spin_time).timeout
	
	reset_modifier(true)
	#gun_status_label.visible = false
	stop_all_barrels()
	is_reloading = false
	reload()


func spin_single_barrel(barrel_idx: int) -> void:
	if barrel_idx >= installed_barrels.size():
		return
	
	is_reloading = true
	release_trigger()
	
	# TODO - move spin arm up/down gun depending on barrel count
	anim_tree.set("parameters/spin_shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	await spin_anim_trigger
	
	_spin_barrel(barrel_idx)
	
	# TODO - replace with a dedicated spin time value now reloading 
	# isn't directly tied to spinning
	await get_tree().create_timer(base_spin_time).timeout
	
	_stop_barrel(barrel_idx)
	is_reloading = false
	reload()


func _spin_barrel(barrel_idx: int) -> void:
	var barrel = installed_barrels[barrel_idx]
	barrel.start_spin()
	var state_machine = anim_tree.get("parameters/barrel_%s_state/playback" % [(barrel_idx + 1)])
	state_machine.travel("spin")
	SoundManager.play_sound(TEMP_sfx_spin, "Gun")
	barrel_spin_started.emit(barrel, barrel_idx)


func stop_all_barrels() -> void:
	for i in installed_barrels.size():
		_stop_barrel(i)


func _stop_barrel(barrel_idx: int) -> void:
	var barrel = installed_barrels[barrel_idx]
	barrel.stop_spin()
	var state_machine = anim_tree.get("parameters/barrel_%s_state/playback" % [(barrel_idx + 1)])
	state_machine.travel("idle")
	SoundManager.stop_sound(TEMP_sfx_spin)
	barrel_spin_stopped.emit(barrel, barrel_idx)
	barrel.get_active_effect().on_effect_set()


func reload():
	# TODO - make this more generic and less tied to spinning barrels so we can call it elsewhere
	if is_reloading:
		return
	if is_jammed:
		play_failed_shoot_sfx()
		return
	
	release_trigger()

	for barrel in installed_barrels:
		barrel.get_active_effect().on_reload_start()
	
	is_reloading = true
	anim_tree.set("parameters/reload_timescale/scale", 1/modified_reload_time)
	anim_tree.set("parameters/reload_shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	
	await reload_anim_end
	is_reloading = false
	anim_tree.set("parameters/reload_timescale/scale", 1)
	
	for barrel in installed_barrels:
		barrel.get_active_effect().on_reload_end()

	magazine_ammo_left = modified_magazine_size
	gun_reloaded.emit()


func _end_reload_anim() -> void:
	reload_anim_end.emit()


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
	modified_ricochet_count = 0
	modified_homing_strength = 0
	modified_recoil = recoil_amount
	modified_screenshake = screenshake_amount
	if reload_reset:
		modified_reload_time = base_reload_time
		modified_magazine_size = base_magazine_size
		modified_projectile_prefab = null


func jam_the_gun(duration: float = 1.0):
	#show_gun_status("Jammed...", Color.DIM_GRAY, duration)

	jam_timer.start(duration)
	is_jammed = true


# TODO - debug use only: make better, more interesting UI effects and hooks for this
func regain_ammo(ammo: int) -> void:
	#show_gun_status("Regained +%s ammo" % [ammo], Color.CYAN)
	SoundManager.play_sound(TEMP_regain_ammo, "Gun")


# TODO - debug use only: make better, more interesting UI effects and hooks for this
func crit_damage(damage: int) -> void:
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
		SoundManager.play_sound(TEMP_sfx_dry, "Gun")
		failed_shoot_sfx_timer.start()


func install_barrel(barrel_prefab: PackedScene) -> void:
	if len(installed_barrels) >= max_barrels:
		return
	
	var barrel_inst = barrel_prefab.instantiate()
	barrel_inst.barrel_effect_changed.connect(_set_barrel_effect_label)
	barrel_container.add_child(barrel_inst)
	_set_barrel_effect_label(barrel_inst, barrel_inst.get_active_effect())
	
	magazine_ammo_left = 0
	
	var barrel_count: int = barrel_container.get_child_count()
	var barrel_idx: int = barrel_count - 1 if barrel_count > 0 else 0 
	
	#barrel.owner_gun = self
	installed_barrels.append(barrel_inst)
	barrel_count = installed_barrels.size()
	
	barrel_equipped.emit(barrel_inst, barrel_idx)
	
	recheck_installed_barrels()
	
	# Re-apply the effects of the currently equipped barrels
	reset_modifier(true)
	for barrel in barrel_container.get_children():
		if barrel == barrel_inst:
			continue
		barrel.get_active_effect().on_effect_set()
	
	await get_tree().physics_frame
	await get_tree().physics_frame
	spin_single_barrel(barrel_count - 1)


func remove_barrel(barrel_idx: int) -> void:
	if len(installed_barrels) == 0:
		return
	
	var barrel: SpinBarrel = barrel_container.get_child(barrel_idx)
	barrel.queue_free()
	barrel_container.remove_child(barrel)
	barrel_unequipped.emit(null, barrel_idx)
	reset_modifier(true)
	recheck_installed_barrels()
	
	# Re-apply the effects of the currently equipped barrels
	for _barrel in barrel_container.get_children():
		_barrel.get_active_effect().on_effect_set()


func recheck_installed_barrels():
	# Wait to make sure barrel actually instantiated or queue_freed
	await get_tree().process_frame
	await get_tree().process_frame
	installed_barrels = []
	for i in range(barrel_container.get_child_count()):
		var barrel = barrel_container.get_child(i)
		barrel.owner_gun = self
		installed_barrels.append(barrel)
		_set_barrel_effect_label(barrel, barrel.get_active_effect())
	
	barrel_count = installed_barrels.size()
	
	for i in barrel_sprites.size():
		var barrel_label: Label3D = barrel_labels[i]
		var state_machine = anim_tree.get("parameters/barrel_%s_state/playback" % [(i + 1)])
		if i < barrel_count:
			state_machine.travel("idle")
			barrel_label.visible = true
		else:
			state_machine.travel("unequip")
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
		var barrel = GameManager.equipped_barrels[i].barrel_prefab
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
	SoundManager.play_sound(TEMP_sfx_reload, "Gun")

func _play_reload_end_sfx() -> void:
	SoundManager.play_sound(TEMP_sfx_click, "Gun")


func create_muzzle_smoke(aim_ray: RayCast3D):
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
