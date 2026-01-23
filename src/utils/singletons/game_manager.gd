extends Node

# FMOD guide https://fmod-gdextension.readthedocs.io/en/latest/user-guide/4-loading-banks/
#            https://www.youtube.com/watch?v=7kD7Q3O5P-s

signal currency_changed(new_currency: int)
signal barrel_purchased(barrel_data: BarrelDataResource)
signal gun_frame_purchased(gun_frame_data: GunFrameResource)
signal barrel_too_expensive(barrel_data: BarrelDataResource)
signal gun_frame_too_expensive(gun_frame_data: GunFrameResource)
signal reroll_cost_changed(new_cost: int)
signal free_rerolls
signal refresh_shop_ui
signal risk_level_changed
signal demo_time_changed

const FPS_LIMIT_ARRAY = [30, 60, 120, 144, 240, 0]
const RESOLUTION_ARRAY = [
	Vector2i(2560, 1440), Vector2i(1920, 1080), Vector2i(1440, 900),
	Vector2i(1366, 768), Vector2i(1280, 720), Vector2i(1024, 768)
]

const CHIP_COST_PER_LEVEL_UP = 500
const BASE_PLAYER_LUCK_THRESHOLD = 0.95
const PLOT_ARMOR_DAMAGE_ABSORB_PERC = 0.25 # Perc of damage taken by player will be absorbed by luck
const PLOT_ARMOR_LUCK_DAMAGE_MULTIPLIER = 4.0 # Luck needed to absorb damage will multiplied by this
const HIGH_ROLLER_BONUS_HEAL_PER_REROLL_TIME = 5
const BASE_FMOD_VOLUME = 5

var pause_ui: PauseUI
var setting_ui: SettingUI
var player: Player
var difficulty_menu: DifficultyMenu
var object_pooling_manager: ObjectPoolingManager
var current_boss_map: Node3D

@onready var main_bgm_emitter: MainBGMEmitter = $MainBGMEmitter

# Inventory
@export var starting_barrels: Array[Resource]
@export var starting_shop_barrels: Array[Resource]
@export var barrel_database: Array[Resource]
@export var debug_barrel_database: Array[Resource]
var equipped_barrels: Array[Resource] = []
var inventory_barrels: Array[Resource] = []
var shop_barrels: Array[Resource] = []

@export var starting_gun_frame: Resource
@export var starting_shop_gun_frame: Array[Resource]
@export var gun_frame_database: Array[Resource]
var equipped_gun_frame: Resource = starting_gun_frame
var inventory_gun_frames: Array[Resource] = []
@onready var shop_gun_frames: Array[Resource] = starting_shop_gun_frame

# Re-rolls
@export var initial_reroll_cost: int = 100
@export var reroll_cost_mult: float = 1.2
var reroll_cost: int = initial_reroll_cost
var is_free_reroll: bool = false:
	set(value):
		is_free_reroll = value
		if is_free_reroll:
			free_rerolls.emit()
var reroll_time = 0

@export var player_currency: int = 0:
	set(value):
		player_currency = max(0, value)
		currency_changed.emit(player_currency)

var player_level = 1
var player_skill_dict = {}
var player_skill_points = 0

var player_gained_first_barrel: bool = false
var barrel_tutorial_shown: bool = false

var tutorial_completed: bool = false

var bosses_defeated: Array[BossCore.BossIdEnum] = []
var all_bosses_defeated: bool = false
var victory_ui_shown: bool = false

var chosen_slot_id = -1
var start_record_timestamp = 0
var total_playtime = 0

# Difficulty modifiers
var selected_level_path: String
var selected_boss_id: BossCore.BossIdEnum
var bet_value = 0
var reward_value = 0
var risk_modifier_level_dict = {
	RiskItem.RiskModifierEnum.INCREASE_BOSS_HP: 0,
	RiskItem.RiskModifierEnum.INCREASE_BOSS_DMG: 0,
	RiskItem.RiskModifierEnum.INCREASE_BOSS_MOVE_ATK_SPEED: 0,
	RiskItem.RiskModifierEnum.INCREASE_BOSS_STATUS_RESIST: 0,
	RiskItem.RiskModifierEnum.INCREASE_PLAYER_SPIN_COST: 0,
	RiskItem.RiskModifierEnum.REDUCE_PLAYER_HEALING: 0,
	RiskItem.RiskModifierEnum.REDUCE_PLAYER_LUCK_BUILD_UP: 0,
	RiskItem.RiskModifierEnum.LIMIT_PLAYER_SPIN_AMOUNT: 0,
	RiskItem.RiskModifierEnum.LIMIT_FIGHT_TIME: 0
}
var boss_ante = 0
var risk_level = 0:
	set(value):
		risk_level = value
		if risk_level >= 15:
			boss_ante = 5
		else:
			boss_ante = int(risk_level / 3)
		risk_level_changed.emit()


# HACK - do this dynamically with level loading/unloading in the elevator
var cached_player_pos_relative_to_elevator_doors: Vector3
var cached_player_rotation: Vector3
var cached_camera_rotation: Vector3

# Setting
@export_range(1.0, 100.0, 0.1) var mouse_sensitivity: float = 50.0
@export_range(60, 120, 1.0) var camera_fov: float = 90:
	set(value):
		if value != camera_fov && player:
			player.player_camera.set_fov(value)
			if player.freecam:
				player.freecam.set_fov(value)
		camera_fov = value
var camera_tilt: bool = true

@export_range(0, 5, 1) var fps_limit_index: int = 2 # Refer to EnumAutoload.FPS_LIMIT_ARRAY
@export_range(0, 6, 1) var resolution_index: int = 1 # Refer to EnumAutoload.RESOLUTION_ARRAY. Not used in FULL_SCREEN
var vsync_option_index: int = 1
@export_range(0, 2, 1) var window_mode_index: int = 1 # From 0 to 2
var scaling_3d: float = 100.0
var enable_elemental_vfx = true # : TODO
var hide_ui = false
var hide_hurt_overlay = false
var hide_damage_number = false
# Accessibility setting flags
var screen_shake_enabled: bool = true
var drunk_blur_enabled: bool = true

@export_range(0, 100, 0.1) var master_audio: float = 80:
	set(value):
		master_audio = value
		update_fmod_bgm_volume_from_setting()
@export_range(0, 100, 0.1) var bgm_audio: float = 100:
	set(value):
		bgm_audio = value
		update_fmod_bgm_volume_from_setting()
@export_range(0, 100, 0.1) var sfx_audio: float = 100
@export_range(0, 100, 0.1) var ui_audio: float = 100
var is_controller_connected: bool = false
var aim_assist_strength: float = 0.5

# DEBUG CHEATS
var CHEAT_oneshot: bool = false
var CHEAT_godmode: bool = false
enum DebugSpinMode {
	ON_RELOAD,
	MANUAL_SPIN,
	SEEDED_AUTO_SPIN,
}
var CHEAT_spin_mode: int = DebugSpinMode.SEEDED_AUTO_SPIN
var CHEAT_freecam: bool = true
var CHEAT_always_inventory: bool = false
var CHEAT_demomode: bool = true
var CHEAT_demomode_timeout: int = 60:
	set(value):
		CHEAT_demomode_timeout = value
		demo_time_changed.emit(CHEAT_demomode_timeout)

@export var sfx_screenshot: AudioStream


#func _init() -> void:
	#var steam_response: Dictionary = Steam.steamInitEx(3926630)
	#print(steam_response)


func _ready() -> void:
	barrel_database.append_array(debug_barrel_database)
	await get_tree().process_frame
	await get_tree().process_frame
	SaveManager.load_setting_config()
	is_controller_connected = Input.get_connected_joypads() != []
	Input.joy_connection_changed.connect(_on_controller_connection)
	main_bgm_emitter.volume = BASE_FMOD_VOLUME
	main_bgm_emitter.play()

func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("toggle_freecam"):
		if CHEAT_freecam:
			# Spawn freecam if not exist, else despawm it
			if player.freecam:
				player._disable_freecam()
			else:
				player._enable_freecam()
	if Input.is_action_just_pressed("debug_increase_timescale"):
		if Engine.time_scale < 1.0:
			Engine.time_scale += 0.1
	elif Input.is_action_just_pressed("debug_decrease_timescale"):
		if Engine.time_scale >= 0.1:
			Engine.time_scale -= 0.1

	if Input.is_action_just_pressed("screenshot"):
		var screen_cap := get_viewport().get_texture().get_image()
		var dir := DirAccess.open("user://")
		if not dir.dir_exists("screenshots"):
			dir.make_dir("screenshots")
		var filename := "user://screenshots/crapshoot_%s.png" % [Time.get_unix_time_from_system()]
		screen_cap.save_png(filename)
		print("Screenshot captured at %s" % filename)
		SoundManager.play_ui_sound(sfx_screenshot)

#region Gun and Barrel
func add_barrel_to_inventory(data: BarrelDataResource):
	if data in inventory_barrels:
		push_warning("Barrel [%s] already collected!" % data.barrel_name)
		return
	inventory_barrels.append(data)


func purchase_barrel(data: BarrelDataResource) -> bool:
	if data.barrel_cost <= player_currency:
		player_currency -= data.barrel_cost
		inventory_barrels.append(data)
		shop_barrels.erase(data)
		refresh_shop_ui.emit()
		barrel_purchased.emit(data)
		return true
	barrel_too_expensive.emit(data)
	return false


## Return error string if cant equipped
func equip_barrel(search_barrel_id: BarrelDataResource.BarrelIdEnum) -> String:
	if player.current_gun.is_reloading:
		return "Can not change barrel while reloading"
	if len(equipped_barrels) >= player.current_gun.max_barrels:
		return "Can not equip more barrels"
	var found_data: BarrelDataResource = null
	for data in inventory_barrels:
		if data.barrel_id == search_barrel_id:
			found_data = data
	if found_data:
		# Check if already equipped archetype
		for barrel in equipped_barrels:
			if barrel.is_archetype_barrel and found_data.is_archetype_barrel:
				return "Can only equip 1 archetype barrel"
		inventory_barrels.erase(found_data)
		equipped_barrels.append(found_data)
		refresh_shop_ui.emit()
		GameManager.player.current_gun.install_barrel(found_data)
		#if found_data.is_archetype_barrel and equipped_barrels.size() != 1:
			#return "Warning: archetype barrel isn't installed in first slot"
	return ""


func remove_barrel(search_barrel_id: BarrelDataResource.BarrelIdEnum) -> String:
	if player.current_gun.is_reloading or player.current_gun.is_spinning:
		return "Can not change barrel while reloading"
	var found_data: BarrelDataResource = null
	var barrel_idx: int = -1
	for i in range(equipped_barrels.size()):
		var data = equipped_barrels[i]
		if data.barrel_id == search_barrel_id:
			found_data = data
			barrel_idx = i
			break
	if found_data:
		equipped_barrels.erase(found_data)
		inventory_barrels.append(found_data)
		refresh_shop_ui.emit()
		GameManager.player.current_gun.remove_barrel(barrel_idx)
	return ""


func purchase_gun_frame(data: GunFrameResource) -> bool:
	if data.frame_cost <= player_currency:
		player_currency -= data.frame_cost
		inventory_gun_frames.append(data)
		shop_gun_frames.erase(data)
		refresh_shop_ui.emit()
		gun_frame_purchased.emit(data)
		return true
	gun_frame_too_expensive.emit(data)
	return false


func equip_gun_frame(search_frame_id: GunFrameResource.GunFrameIdEnum) -> String:
	if player.current_gun.is_reloading:
		return "Can not change gun frame while reloading"
	var found_data: GunFrameResource = null
	for data in inventory_gun_frames:
		if data.frame_id == search_frame_id:
			found_data = data
	if found_data:
		inventory_gun_frames.append(equipped_gun_frame)
		equipped_gun_frame = found_data
		inventory_gun_frames.erase(found_data)
		GameManager.player.gun.set_stat_from_gun_frame()
		refresh_shop_ui.emit()
	return ""


func purchase_reroll() -> bool:
	if reroll_time == 0:
		reroll_cost = int(reroll_cost * get_risk_spin_cost_mult())
	if GameManager.current_boss_map and GameManager.current_boss_map.is_tutorial:
		reroll_cost = 100
	if (player_currency >= reroll_cost and reroll_time < get_risk_limit_spin_amount()) or is_free_reroll:
		if not is_free_reroll:
			player_currency -= reroll_cost
			# Increase the cost of re-rolling for this fight
			# reroll_cost = int(reroll_cost * reroll_cost_mult)
			reroll_cost = int(reroll_cost * (reroll_cost_mult + (GameManager.get_risk_spin_cost_mult() - 1)))

			reroll_time += 1
		reroll_cost_changed.emit(reroll_cost)
		return true
	return false


func reset_reroll_cost() -> void:
	reroll_cost = initial_reroll_cost
	reroll_cost_changed.emit(reroll_cost)
	reroll_time = 0
#endregion

#region Save helper
func load_new_save_data():
	tutorial_completed = false

	# Generate reload-spin threshold values for all barrels on save game creation
	randomize()
	for barrel_data in barrel_database:
		# Weight the ranges so we get more middle of the road values
		var range_weight: float = randf()
		if range_weight < 0.25:
			barrel_data.reloads_before_spin = randi_range(1, 2)
		elif range_weight < 0.8:
			barrel_data.reloads_before_spin = randi_range(3, 5)
		else:
			barrel_data.reloads_before_spin = randi_range(6, 7)

	for data in starting_barrels:
		var idx: int = barrel_database.find(data)
		data.reloads_before_spin = barrel_database[idx].reloads_before_spin
		if data not in equipped_barrels:
			equipped_barrels.append(data)
	for data in starting_shop_barrels:
		var idx: int = barrel_database.find(data)
		data.reloads_before_spin = barrel_database[idx].reloads_before_spin
		shop_barrels.append(data)

func reset_current_save_data():
	equipped_barrels = []
	inventory_barrels = []
	shop_barrels = []
	player_currency = 0
	player_gained_first_barrel = false
	barrel_tutorial_shown = false
	bosses_defeated = []
	all_bosses_defeated = false
	victory_ui_shown = false
	chosen_slot_id = -1
	start_record_timestamp = 0
	total_playtime = 0
	tutorial_completed = false
	reset_difficulty_modifier()


func start_record_playtime():
	start_record_timestamp = Time.get_ticks_msec()

func update_total_playtime():
	var current_time = Time.get_ticks_msec()
	var played_time = current_time - start_record_timestamp
	total_playtime += played_time
#endregion

#region Boss stuff
func show_boss_special_dialog(content: String, duration: float):
	var original_sm_process_mode = SoundManager.process_mode
	SoundManager.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	GameManager.player.boss_special_dialog_label.text = content
	GameManager.player.boss_special_dialog.visible = true
	await get_tree().create_timer(duration).timeout
	GameManager.player.boss_special_dialog.visible = false
	get_tree().paused = false
	SoundManager.process_mode = original_sm_process_mode


# Boss telegraph time can be modified by difficulty or Poker Face skill
func get_boss_telegraph_time_multiplier() -> float:
	var mult = 1.0
	# Poker Face skill
	if player_skill_dict.has(SkillItemUI.SkillIdEnum.POKER_FACE) and player.luck_component.is_high_luck():
		mult += 0.1 * player_skill_dict[SkillItemUI.SkillIdEnum.POKER_FACE]
	# If difficulty also modified boss telegraph time, add it here
	#

	return mult

func get_boss_chip_amount_drop_multiplier() -> float:
	var mult = 1.0
	# Blessed Chip skill
	if player_skill_dict.has(SkillItemUI.SkillIdEnum.BLESSED_CHIP):
		match int(GameManager.player_skill_dict[SkillItemUI.SkillIdEnum.BLESSED_CHIP]):
			1:
				mult -= 0.1
			2:
				mult -= 0.2
			3:
				mult -= 0.3
			4:
				mult -= 0.4
	return mult
#endregion

#region Risk modifier
func reset_difficulty_modifier():
	risk_modifier_level_dict = {
		RiskItem.RiskModifierEnum.INCREASE_BOSS_HP: 0,
		RiskItem.RiskModifierEnum.INCREASE_BOSS_DMG: 0,
		RiskItem.RiskModifierEnum.INCREASE_BOSS_MOVE_ATK_SPEED: 0,
		RiskItem.RiskModifierEnum.INCREASE_BOSS_STATUS_RESIST: 0,
		RiskItem.RiskModifierEnum.INCREASE_PLAYER_SPIN_COST: 0,
		RiskItem.RiskModifierEnum.REDUCE_PLAYER_HEALING: 0,
		RiskItem.RiskModifierEnum.REDUCE_PLAYER_LUCK_BUILD_UP: 0,
		RiskItem.RiskModifierEnum.LIMIT_PLAYER_SPIN_AMOUNT: 0,
		RiskItem.RiskModifierEnum.LIMIT_FIGHT_TIME: 0
	}
	risk_level = 0
	boss_ante = 0
	bet_value = 0
	reward_value = 0

func get_risk_max_hp_mult() -> float:
	var value = 1 + GameManager.risk_modifier_level_dict[RiskItem.RiskModifierEnum.INCREASE_BOSS_HP] * \
		RiskItem.risk_value_per_level_dict[RiskItem.RiskModifierEnum.INCREASE_BOSS_HP]
	return value

func get_risk_dmg_mult() -> float:
	var value = 1 + GameManager.risk_modifier_level_dict[RiskItem.RiskModifierEnum.INCREASE_BOSS_DMG] * \
		RiskItem.risk_value_per_level_dict[RiskItem.RiskModifierEnum.INCREASE_BOSS_DMG]
	return value

func get_risk_atk_move_speed_mult() -> float:
	var value = 1 + GameManager.risk_modifier_level_dict[RiskItem.RiskModifierEnum.INCREASE_BOSS_MOVE_ATK_SPEED] * \
		RiskItem.risk_value_per_level_dict[RiskItem.RiskModifierEnum.INCREASE_BOSS_MOVE_ATK_SPEED]
	return value

func get_risk_status_resist_mult() -> float:
	var value = 1 + GameManager.risk_modifier_level_dict[RiskItem.RiskModifierEnum.INCREASE_BOSS_STATUS_RESIST] * \
		RiskItem.risk_value_per_level_dict[RiskItem.RiskModifierEnum.INCREASE_BOSS_STATUS_RESIST]
	return value

func get_risk_spin_cost_mult() -> float:
	var value = 1 + GameManager.risk_modifier_level_dict[RiskItem.RiskModifierEnum.INCREASE_PLAYER_SPIN_COST] * \
		RiskItem.risk_value_per_level_dict[RiskItem.RiskModifierEnum.INCREASE_PLAYER_SPIN_COST]
	return value

func get_risk_healing_effectiveness_mult() -> float:
	var value = 1 - GameManager.risk_modifier_level_dict[RiskItem.RiskModifierEnum.REDUCE_PLAYER_HEALING] * \
		RiskItem.risk_value_per_level_dict[RiskItem.RiskModifierEnum.REDUCE_PLAYER_HEALING]
	return value

func get_risk_luck_buildup_mult() -> float:
	var value = 1 - GameManager.risk_modifier_level_dict[RiskItem.RiskModifierEnum.REDUCE_PLAYER_LUCK_BUILD_UP] * \
		RiskItem.risk_value_per_level_dict[RiskItem.RiskModifierEnum.REDUCE_PLAYER_LUCK_BUILD_UP]
	return value

func get_risk_limit_spin_amount() -> int:
	var value = 999999
	if risk_modifier_level_dict[RiskItem.RiskModifierEnum.LIMIT_PLAYER_SPIN_AMOUNT] > 0:
		value = RiskItem.STARTING_MAX_LIMIT_PLAYER_SPIN_AMOUNT - \
			((risk_modifier_level_dict[RiskItem.RiskModifierEnum.LIMIT_PLAYER_SPIN_AMOUNT] - 1) * \
			RiskItem.risk_value_per_level_dict[RiskItem.RiskModifierEnum.LIMIT_PLAYER_SPIN_AMOUNT])
	return value
#endregion

#region Other
func _on_controller_connection(_device: int, connected: bool):
	is_controller_connected = connected

## Level can be Menu, Lobby, Roulette, Slotty, Bartender, GenericBossAftermath, PitbossHallway,
## PitbossMainfight, ChipbossStart, ChipbossInt , BlackjackStart, TutorialBossfight, Tutorial1, Tutorial2,
func change_fmod_bgm_music_state(music_state: String) -> void:
	main_bgm_emitter.set_parameter("MusicState", music_state)

func change_fmod_bgm_player_is_dead(dead: bool) -> void:
	main_bgm_emitter.set_parameter("playerIsDead", 1 if dead else 0)

func change_fmod_bgm_menu_is_up(menu_up: bool) -> void:
	main_bgm_emitter.set_parameter("menuIsUp", 1 if menu_up else 0)

func update_fmod_bgm_volume_from_setting() -> void:
	main_bgm_emitter.volume = BASE_FMOD_VOLUME * (GameManager.master_audio / 100.0) * (GameManager.bgm_audio / 100.0)

func create_and_add_status_effect(display_name: String, status_code: String, modified_stat: StatusEffect.PlayerStatEnum,
	value: float, modify_type: StatusEffect.ModifyType, duration: float = StatusEffect.INFINITE_DURATION, is_bad_effect: bool = false,
	show_duration_ui = false, status_icon: Texture2D = null, is_luck_buff: bool = false):
	var status_effect = StatusEffect.new()
	status_effect.display_name = display_name
	status_effect.status_code = status_code
	status_effect.modified_stat = modified_stat
	status_effect.value = value
	status_effect.modify_type = modify_type
	status_effect.duration = duration
	status_effect.is_bad_effect = is_bad_effect
	status_effect.show_duration_ui = show_duration_ui
	status_effect.show_value_on_ui = false
	status_effect.status_icon = status_icon
	status_effect.is_luck_buff = is_luck_buff

	player.add_status_effect(status_effect)
#endregion
