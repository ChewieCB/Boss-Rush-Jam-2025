extends Node

signal currency_changed(new_currency: int)
signal barrel_purchased(barrel_data: BarrelDataResource)
signal barrel_too_expensive(barrel_data: BarrelDataResource)
signal reroll_cost_changed(new_cost: int)
signal free_rerolls
signal refresh_shop_ui

const FPS_LIMIT_ARRAY = [30, 60, 120, 144, 240, 0]
const RESOLUTION_ARRAY = [
	Vector2i(2560, 1440), Vector2i(1920, 1080), Vector2i(1440, 900),
	Vector2i(1366, 768), Vector2i(1280, 720), Vector2i(1024, 768)
]

var pause_ui: PauseUI
var setting_ui: SettingUI
var player: Player

# Barrels
var equipped_barrels: Array[BarrelDataResource] = []
var inventory_barrels: Array[BarrelDataResource] = []
var shop_barrels: Array[BarrelDataResource] = []

@export var starting_barrels: Array[BarrelDataResource]
@export var starting_shop_barrels: Array[BarrelDataResource]
@export var barrel_database: Array[BarrelDataResource]

# Re-rolls
@export var initial_reroll_cost: int = 200
@export var reroll_cost_mult: float = 1.2
var reroll_cost: int = initial_reroll_cost
var is_free_reroll: bool = false:
	set(value):
		is_free_reroll = value
		if is_free_reroll:
			free_rerolls.emit()

@export var player_currency: int = 0:
	set(value):
		player_currency = value
		currency_changed.emit(player_currency)

var player_gained_first_barrel: bool = false
var barrel_tutorial_shown: bool = false

var bosses_defeated: Array[BossCore.BossIdEnum] = []
var all_bosses_defeated: bool = false
var victory_ui_shown: bool = false

var chosen_slot_id = -1
var start_record_timestamp = 0
var total_playtime = 0

# HACK - do this dynamically with level loading/unloading in the elevator
var cached_player_pos_relative_to_elevator_doors: Vector3
var cached_player_rotation: Vector3
var cached_camera_rotation: Vector3

# SFX
# TODO - find a good generic solution for calling these outside of the shop
@export var sfx_purchase: AudioStream
@export var sfx_too_expensive: AudioStream

# Setting
@export_range(1.0, 100.0, 0.1) var mouse_sensitivity: float = 50.0
@export_range(60, 120, 1.0) var camera_fov: float = 90:
	set(value):
		if value != camera_fov && player:
			player.player_camera.set_fov(value)
		camera_fov = value
var camera_tilt: bool = true

@export_range(0, 5, 1) var fps_limit_index: int = 2 # Refer to EnumAutoload.FPS_LIMIT_ARRAY
@export_range(0, 6, 1) var resolution_index: int = 1 # Refer to EnumAutoload.RESOLUTION_ARRAY. Not used in FULL_SCREEN
var vsync_option_index: int = 1
@export_range(0, 2, 1) var window_mode_index: int = 1 # From 0 to 2
var scaling_3d: float = 100.0
var hide_ui = false
@export_range(0, 100, 0.1) var master_audio: float = 80
@export_range(0, 100, 0.1) var bgm_audio: float = 100
@export_range(0, 100, 0.1) var sfx_audio: float = 100
@export_range(0, 100, 0.1) var ui_audio: float = 100


func _ready() -> void:
	if len(barrel_database) == 0:
		load_barrel_database()
	await get_tree().process_frame
	await get_tree().process_frame
	SaveManager.load_setting_config()


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
		return "Can not equip more barrel"
	var found_data: BarrelDataResource = null
	for data in inventory_barrels:
		if data.barrel_id == search_barrel_id:
			found_data = data
	if found_data:
		# Check if already equipped archetype
		for barrel in equipped_barrels:
			if barrel.is_archetype_barrel and found_data.is_archetype_barrel:
				return "Can only equip max 1 archetype barrel"
		inventory_barrels.erase(found_data)
		equipped_barrels.append(found_data)
		refresh_shop_ui.emit()
		GameManager.player.current_gun.install_barrel(found_data.barrel_prefab)
	return ""


func remove_barrel(search_barrel_id: BarrelDataResource.BarrelIdEnum) -> String:
	if player.current_gun.is_reloading:
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


func purchase_reroll() -> bool:
	if player_currency >= reroll_cost or is_free_reroll:
		if not is_free_reroll:
			player_currency -= reroll_cost
			# Increase the cost of re-rolling for this fight
			reroll_cost *= reroll_cost_mult
			reroll_cost_changed.emit(reroll_cost)
		SoundManager.play_sound(sfx_purchase)
		return true
	SoundManager.play_sound(sfx_too_expensive)
	return false


func reset_reroll_cost() -> void:
	reroll_cost = initial_reroll_cost
	reroll_cost_changed.emit(reroll_cost)


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


func load_barrel_database():
	var directory_path = "res://src/player/barrel/resource/"
	var tres_files: Array[BarrelDataResource] = []
	var dir = DirAccess.open(directory_path)

	if dir:
		var files = dir.get_files() # Get all files in the directory
		for file in files:
			if file.ends_with(".tres"):
				var resource = ResourceLoader.load(directory_path + "/" + file)
				if resource:
					tres_files.append(resource as BarrelDataResource)
	else:
		print("Failed to open directory: ", directory_path)
	barrel_database = tres_files


func load_new_save_data():
	for data in starting_barrels:
		equipped_barrels.append(data)
	for data in starting_shop_barrels:
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


func start_record_playtime():
	start_record_timestamp = Time.get_ticks_msec()

func update_total_playtime():
	var current_time = Time.get_ticks_msec()
	var played_time = current_time - start_record_timestamp
	total_playtime += played_time
