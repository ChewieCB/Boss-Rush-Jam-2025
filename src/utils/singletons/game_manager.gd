extends Node

const FPS_LIMIT_ARRAY = [30, 60, 120, 144, 240, 0]
const RESOLUTION_ARRAY = [
	Vector2i(2560, 1440), Vector2i(1920, 1080), Vector2i(1440, 900),
	Vector2i(1366, 768), Vector2i(1280, 720), Vector2i(1024, 768)
]

var pause_ui: PauseUI
var player: Player

var equipped_barrels: Array[BarrelDataResource] = []
var inventory_barrels: Array[BarrelDataResource] = []

# HACK - do this dynamically with level loading/unloading in the elevator
var cached_player_pos_relative_to_elevator_doors: Vector3
var cached_player_rotation: Vector3
var cached_camera_rotation: Vector3

# Setting
@export_range(1.0, 100.0, 0.1) var mouse_sensitivity: float = 50.0

@export_range(60, 120, 1.0) var camera_fov: float = 90:
	set(value):
		if value != camera_fov:
			player.player_camera.set_fov(value)
		camera_fov = value
var camera_tilt: bool = true

@export_range(0, 5, 1) var fps_limit_index: int = 2 # Refer to EnumAutoload.FPS_LIMIT_ARRAY
@export_range(0, 6, 1) var resolution_index: int = 1 # Refer to EnumAutoload.RESOLUTION_ARRAY. Not used in FULL_SCREEN
var vsync_option_index: int = 1
@export_range(0, 2, 1) var window_mode_index: int = 1 # From 0 to 2
var scaling_3d: float = 100.0
@export_range(0, 100, 0.1) var master_audio: float = 80
@export_range(0, 100, 0.1) var bgm_audio: float = 100
@export_range(0, 100, 0.1) var sfx_audio: float = 100
@export_range(0, 100, 0.1) var ui_audio: float = 100


func add_barrel_to_inventory(data: BarrelDataResource):
	if data in inventory_barrels:
		push_warning("Barrel [%s] already collected!" % data.barrel_name)
		return
	inventory_barrels.append(data)

func equip_barrel(search_barrel_id: BarrelDataResource.BarrelIdEnum):
	if player.current_gun.is_reloading:
		return
	if len(equipped_barrels) >= player.current_gun.max_barrels:
		return
	var found_data: BarrelDataResource = null
	for data in inventory_barrels:
		if data.barrel_id == search_barrel_id:
			found_data = data
	if found_data:
		inventory_barrels.erase(found_data)
		equipped_barrels.append(found_data)
		GameManager.player.inventory_ui.full_refresh_ui()
		GameManager.player.current_gun.install_barrel(found_data.barrel_prefab)

func remove_barrel(search_barrel_id: BarrelDataResource.BarrelIdEnum):
	if player.current_gun.is_reloading:
		return
	var found_data: BarrelDataResource = null
	for data in equipped_barrels:
		if data.barrel_id == search_barrel_id:
			found_data = data
	if found_data:
		equipped_barrels.erase(found_data)
		inventory_barrels.append(found_data)
		GameManager.player.inventory_ui.full_refresh_ui()
		GameManager.player.current_gun.remove_barrel(search_barrel_id)
