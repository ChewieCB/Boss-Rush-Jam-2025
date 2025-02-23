extends Node

var save_data_is_loaded = false
var is_saving = false

func convert_resource_to_id(array_resource: Array) -> Array[int]:
	var result: Array[int] = []
	for elem in array_resource:
		result.append(elem.barrel_id)
	return result

func convert_id_to_resource(array_id: Array) -> Array[BarrelDataResource]:
	var result: Array[BarrelDataResource] = []
	for elem in array_id:
		for item in GameManager.barrel_database:
			if item.barrel_id == elem:
				result.append(item)
	return result


func convert_id_to_boss_enum(array_id: Array) -> Array[BossCore.BossIdEnum]:
	var result: Array[BossCore.BossIdEnum] = []
	for elem in array_id:
		result.append(elem as BossCore.BossIdEnum)
	return result


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


func save_game(slot_id: int = 0):
	is_saving = true
	var save_dict = {
		"player_currency": GameManager.player_currency,
		"equipped_barrels": convert_resource_to_id(GameManager.equipped_barrels),
		"inventory_barrels": convert_resource_to_id(GameManager.inventory_barrels),
		"shop_barrels": convert_resource_to_id(GameManager.shop_barrels),
		"player_gained_first_barrel": GameManager.player_gained_first_barrel,
		"barrel_tutorial_shown": GameManager.barrel_tutorial_shown,
		"bosses_defeated": GameManager.bosses_defeated,
		"victory_ui_shown": GameManager.victory_ui_shown,
	}
	var save_file = FileAccess.open(get_savefile_name(slot_id), FileAccess.WRITE)
	var json_string = JSON.stringify(save_dict)
	save_file.store_line(json_string)
	is_saving = false

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


func load_game(slot_id: int = 0):
	save_data_is_loaded = true

	var save_data = load_data_only(slot_id)
	if save_data.is_empty():
		return

	GameManager.player_currency = save_data["player_currency"]
	GameManager.equipped_barrels = convert_id_to_resource(save_data["equipped_barrels"])
	GameManager.inventory_barrels = convert_id_to_resource(save_data["inventory_barrels"])
	GameManager.shop_barrels = convert_id_to_resource(save_data["shop_barrels"])
	GameManager.player_gained_first_barrel = save_data["player_gained_first_barrel"]
	GameManager.barrel_tutorial_shown = save_data["barrel_tutorial_shown"]
	GameManager.bosses_defeated = convert_id_to_boss_enum(save_data["bosses_defeated"])
	GameManager.victory_ui_shown = save_data["victory_ui_shown"]


func get_savefile_name(slot_id: int) -> String:
	return "user://savegame_slot{0}.save".format([slot_id])
