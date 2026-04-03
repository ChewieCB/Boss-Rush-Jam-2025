extends Node

# On Windows, save files are located in C:\Users\[Name]\AppData\Roaming\Godot\app_userdata\Crapshoot

# Change this manually everytime there is a change to save format or item structure.
# We can used them to patch or fix save data from older version.
const SAVE_VERSION: int = 2

var save_data_is_loaded = false
var is_saving = false

signal started_saving
signal finished_saving
signal savefile_loaded
signal setting_config_loaded


enum ResourceTypeEnum {
	NONE,
	BARREL,
	GUN_FRAME,
}


func delete_save_file(slot_id: int):
	var save_path = get_savefile_name(slot_id)
	var dir = DirAccess.open("user://")
	
	if dir and dir.file_exists(save_path):
		var result = dir.remove(save_path)
		if result == OK:
			print("Save file deleted successfully.")
		else:
			print("Failed to delete save file.")
	else:
		print("Save file does not exist.")


func save_game(slot_id):
	is_saving = true
	started_saving.emit()
	if not GameManager.equipped_gun_frame:
		GameManager.equipped_gun_frame = GameManager.starting_gun_frame
	var save_dict = {
		# Stats
		"player_currency": GameManager.player_currency,
		"player_level": GameManager.player_level,
		"bosses_defeated": GameManager.bosses_defeated,
		"player_skill_points": GameManager.player_skill_points,
		"player_skill_dict": GameManager.player_skill_dict,
		
		# Luck
		"luck_trigger_dict": LuckHandler.luck_trigger_dict,
		
		# Inventory & Shop
		"equipped_barrels": convert_resources_to_ids(GameManager.equipped_barrels, ResourceTypeEnum.BARREL),
		"inventory_barrels": convert_resources_to_ids(GameManager.inventory_barrels, ResourceTypeEnum.BARREL),
		"shop_barrels": convert_resources_to_ids(GameManager.shop_barrels, ResourceTypeEnum.BARREL),
		"equipped_gun_frame": convert_resources_to_ids([GameManager.equipped_gun_frame], ResourceTypeEnum.GUN_FRAME).front(),
		"inventory_gun_frames": convert_resources_to_ids(GameManager.inventory_gun_frames, ResourceTypeEnum.GUN_FRAME),
		"shop_gun_frames": convert_resources_to_ids(GameManager.shop_gun_frames, ResourceTypeEnum.GUN_FRAME),

		# First time player flags
		"victory_ui_shown": GameManager.victory_ui_shown,
		"tutorial_completed": GameManager.tutorial_completed,
		"player_gained_first_barrel": GameManager.player_gained_first_barrel,
		"barrel_tutorial_shown": GameManager.barrel_tutorial_shown,

		# Metadata
		"total_playtime": GameManager.total_playtime,
		"save_version": SAVE_VERSION
	}
	var save_file = FileAccess.open(get_savefile_name(slot_id), FileAccess.WRITE)
	var json_string = JSON.stringify(save_dict)
	save_file.store_line(json_string)
	is_saving = false
	finished_saving.emit()

func load_data_only(slot_id: int) -> Dictionary:
	var save_data: Dictionary = {}
	if not FileAccess.file_exists(get_savefile_name(slot_id)):
		return save_data # Error! We don't have a save to load.

	var save_file = FileAccess.open(get_savefile_name(slot_id), FileAccess.READ)
	while save_file.get_position() < save_file.get_length():
		var json_string = save_file.get_line()
		var json = JSON.new()

		var parse_result = json.parse(json_string)
		if not parse_result == OK:
			print("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())
			continue
		for key in json.data.keys():
			save_data[key] = json.data[key]

	return save_data


func load_game(slot_id):
	save_data_is_loaded = true
	var save_data: Dictionary = load_data_only(slot_id)
	if save_data.is_empty():
		GameManager.load_new_save_data()
		savefile_loaded.emit()
		return

	save_data = patch_save_version(save_data)

	# Stats
	GameManager.player_currency = save_data.get("player_currency", 0)
	GameManager.player_level = save_data.get("player_level", 1)
	GameManager.player_skill_points = save_data.get("player_skill_points", 0)
	GameManager.player_skill_dict = convert_id_to_skill_enum(save_data.get("player_skill_dict", {}))
	GameManager.bosses_defeated = convert_id_to_boss_enum(save_data.get("bosses_defeated", []))
	
	# Luck
	LuckHandler.luck_trigger_dict = save_data.get("luck_trigger_dict", {})
	if LuckHandler.luck_trigger_dict == {}:
		LuckHandler.reset_luck_triggers()
	
	# Inventory & Shop
	# These don't use save_data.get() since if it corrupted, it better to know about the error right away and not overwrite the save
	GameManager.equipped_barrels = convert_ids_to_resources(save_data["equipped_barrels"], ResourceTypeEnum.BARREL)
	GameManager.inventory_barrels = convert_ids_to_resources(save_data["inventory_barrels"], ResourceTypeEnum.BARREL)
	GameManager.shop_barrels = convert_ids_to_resources(save_data["shop_barrels"], ResourceTypeEnum.BARREL)
	GameManager.equipped_gun_frame = convert_ids_to_resources([save_data["equipped_gun_frame"]], ResourceTypeEnum.GUN_FRAME).front()
	GameManager.inventory_gun_frames = convert_ids_to_resources(save_data["inventory_gun_frames"], ResourceTypeEnum.GUN_FRAME)
	GameManager.shop_gun_frames = convert_ids_to_resources(save_data["shop_gun_frames"], ResourceTypeEnum.GUN_FRAME)

	# First time player flags
	GameManager.player_gained_first_barrel = save_data.get("player_gained_first_barrel", false)
	GameManager.barrel_tutorial_shown = save_data.get("barrel_tutorial_shown", false)
	GameManager.victory_ui_shown = save_data.get("victory_ui_shown", false)
	GameManager.tutorial_completed = save_data.get("tutorial_completed", false)

	# Metadata
	GameManager.total_playtime = save_data.get("total_playtime", 0)
	var _this_file_save_version = save_data.get("save_version", SAVE_VERSION)
	
	check_for_new_update_barrels()
	
	savefile_loaded.emit()

func get_savefile_name(slot_id: int) -> String:
	return "user://savegame_slot{0}.save".format([slot_id])


func save_setting_config():
	var config = ConfigFile.new()

	var serialized_keybinding_data: String = InputHelper.serialize_inputs_for_actions()

	config.set_value("Control", "mouse_sensitivity", GameManager.mouse_sensitivity)
	config.set_value("Control", "controller_deadzone", GameManager.controller_deadzone)
	config.set_value("Control", "aim_assist_strength", GameManager.aim_assist_strength)
	config.set_value("Control", "keybinding", serialized_keybinding_data)
	config.set_value("Graphic", "camera_fov", GameManager.camera_fov)
	config.set_value("Graphic", "camera_tilt", GameManager.camera_tilt)
	config.set_value("Graphic", "fps_limit_index", GameManager.fps_limit_index)
	config.set_value("Graphic", "resolution_index", GameManager.resolution_index)
	config.set_value("Graphic", "window_mode_index", GameManager.window_mode_index)
	config.set_value("Graphic", "scaling_3d", GameManager.scaling_3d)
	config.set_value("Graphic", "hide_ui", GameManager.hide_ui)
	config.set_value("Graphic", "hide_damage_number", GameManager.hide_damage_number)
	config.set_value("Graphic", "hide_hurt_overlay", GameManager.hide_hurt_overlay)
	config.set_value("Graphic", "screen_shake_enabled", GameManager.screen_shake_enabled)
	config.set_value("Graphic", "drunk_blur_enabled", GameManager.drunk_blur_enabled)
	config.set_value("Audio", "master_audio", GameManager.master_audio)
	config.set_value("Audio", "bgm_audio", GameManager.bgm_audio)
	config.set_value("Audio", "sfx_audio", GameManager.sfx_audio)
	config.set_value("Audio", "ui_audio", GameManager.ui_audio)
	config.set_value("DEBUG", "god_mode", GameManager.CHEAT_godmode)
	config.set_value("DEBUG", "demo_mode", GameManager.CHEAT_demomode)
	config.set_value("DEBUG", "demo_mode_timeout", GameManager.CHEAT_demomode_timeout)
	config.set_value("DEBUG", "always_inventory", GameManager.CHEAT_always_inventory)
	config.set_value("DEBUG", "boss_one_shot", GameManager.CHEAT_oneshot)
	config.set_value("DEBUG", "freecam", GameManager.CHEAT_freecam)
	
	config.save("user://setting.cfg")


func load_setting_config():
	var config = ConfigFile.new()

	var err = config.load("user://setting.cfg")

	# If the file didn't load, ignore it.
	if err != OK:
		return

	var serialized_keybinding_data = config.get_value("Control", "keybinding", "")
	if serialized_keybinding_data != "":
		InputHelper.deserialize_inputs_for_actions(serialized_keybinding_data)

	GameManager.mouse_sensitivity = config.get_value("Control", "mouse_sensitivity", 50.0)
	GameManager.controller_deadzone = config.get_value("Control", "controller_deadzone", 0.1)
	GameManager.aim_assist_strength = config.get_value("Control", "aim_assist_strength", 0.5)
	GameManager.camera_fov = config.get_value("Graphic", "camera_fov", 90)
	GameManager.camera_tilt = config.get_value("Graphic", "camera_tilt", true)
	GameManager.fps_limit_index = config.get_value("Graphic", "fps_limit_index", 2)
	GameManager.resolution_index = config.get_value("Graphic", "resolution_index", 1)
	GameManager.window_mode_index = config.get_value("Graphic", "window_mode_index", 1)
	GameManager.scaling_3d = config.get_value("Graphic", "scaling_3d", 100.0)
	GameManager.screen_shake_enabled = config.get_value("Graphic", "screen_shake_enabled", true)
	GameManager.drunk_blur_enabled = config.get_value("Graphic", "drunk_blur_enabled", true)
	GameManager.master_audio = config.get_value("Audio", "master_audio", 80)
	GameManager.bgm_audio = config.get_value("Audio", "bgm_audio", 100)
	GameManager.sfx_audio = config.get_value("Audio", "sfx_audio", 100)
	GameManager.ui_audio = config.get_value("Audio", "ui_audio", 100)
	
	GameManager.CHEAT_godmode = config.get_value("DEBUG", "god_mode", false)
	GameManager.CHEAT_demomode = config.get_value("DEBUG", "demo_mode", false)
	GameManager.CHEAT_demomode_timeout = config.get_value("DEBUG", "demo_mode_timeout", 5)
	GameManager.CHEAT_always_inventory = config.get_value("DEBUG", "always_inventory", false)
	GameManager.CHEAT_oneshot = config.get_value("DEBUG", "boss_one_shot", false)
	GameManager.CHEAT_freecam = config.get_value("DEBUG", "freecam", false)
	
	setting_config_loaded.emit()

# If we update the game and add new barrel into GameManager's shop,
# this will look for it
func check_for_new_update_barrels():
	for barrel_data in GameManager.starting_shop_barrels:
		if not GameManager.equipped_barrels.has(barrel_data) and \
		not GameManager.inventory_barrels.has(barrel_data) and \
		not GameManager.shop_barrels.has(barrel_data):
			GameManager.shop_barrels.append(barrel_data)


func convert_resources_to_ids(array_resource: Array[Resource], resource_type: ResourceTypeEnum) -> Array[int]:
	var result: Array[int] = []
	match resource_type:
		ResourceTypeEnum.BARREL:
			for elem in array_resource:
				if not elem.barrel_name.to_lower().contains("debug"):
					var barrel: BarrelDataResource = elem as BarrelDataResource
					result.append(barrel.barrel_id)
		ResourceTypeEnum.GUN_FRAME:
			for elem in array_resource:
				var gun_frame: GunFrameResource = elem as GunFrameResource
				result.append(gun_frame.frame_id)
	return result


func convert_ids_to_resources(array_id: Array, resource_type: ResourceTypeEnum) -> Array[Resource]:
	var result: Array[Resource] = []
	match resource_type:
		ResourceTypeEnum.BARREL:
			if len(GameManager.barrel_database) == 0:
				push_warning("GameManger.barrel_database is empty / not loaded yet!")
			for elem in array_id:
				for item in GameManager.barrel_database:
					var barrel_data_item: BarrelDataResource = item as BarrelDataResource
					if barrel_data_item.barrel_id == elem:
						result.append(item)
		ResourceTypeEnum.GUN_FRAME:
			if len(GameManager.gun_frame_database) == 0:
				push_warning("GameManger.gun_frame_database is empty / not loaded yet!")
			for elem in array_id:
				for item in GameManager.gun_frame_database:
					var gun_frame_data_item: GunFrameResource = item as GunFrameResource
					if gun_frame_data_item.frame_id == elem:
						result.append(item)
	return result


func convert_id_to_boss_enum(array_id: Array) -> Array[BossCore.BossIdEnum]:
	var result: Array[BossCore.BossIdEnum] = []
	for elem in array_id:
		result.append(elem as BossCore.BossIdEnum)
	return result

func convert_id_to_skill_enum(dict_id: Dictionary) -> Dictionary:
	var result = {}
	for key in dict_id:
		var new_key = (key as SkillItemUI.SkillIdEnum)
		result[new_key] = dict_id[key]
	return result


func patch_save_version(save_data) -> Dictionary:
	if save_data.has("save_version"):
		if save_data["save_version"] == SAVE_VERSION:
			return save_data
	else:
		save_data["save_version"] = 1

	while save_data["save_version"] < SAVE_VERSION:
		if save_data["save_version"] == 1:
			save_data = patch_save_version_1_to_2(save_data)
	return save_data


func patch_save_version_1_to_2(save_data: Dictionary) -> Dictionary:
	# What changed: Added Gun Frame system, retire Archetype barrels
	# TODO: Remove archetype barrels from inventory
	save_data["equipped_gun_frame"] = 2
	save_data["inventory_gun_frames"] = []
	save_data["shop_gun_frames"] = [3, 4]
	save_data["save_version"] = 2
	return save_data
