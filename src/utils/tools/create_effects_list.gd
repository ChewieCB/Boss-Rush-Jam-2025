@tool
extends EditorScript

const BARREL_EFFECT_RESOURCE_DIR_PATH: String = "res://src/player/barrel/resource/"
const BARREL_EFFECT_CSV_OUTPUT_PATH: String = "res://config/barrel_effects.csv"


func collect_current_effect_resources() -> Dictionary:
	# Get each resource in the barrel effect resources dir and create a struct
	# to store the name, description, etc. of each
	var effects_dict: Dictionary = {}
	
	var dir = DirAccess.open(BARREL_EFFECT_RESOURCE_DIR_PATH)
	if dir:
		dir.list_dir_begin()
		var files: PackedStringArray = dir.get_files()
		var current_dir: String = dir.get_current_dir()
		for file in files:
			var full_path: String = current_dir + "/" + file
			if full_path.contains(".tres"):
				var base_name: String = file.trim_suffix(".tres")
				var res: Resource = load(full_path)
				effects_dict[base_name] = load(full_path)
	
	return effects_dict


func create_csv(effects_dict: Dictionary) -> void:
	var output_file = FileAccess.open(BARREL_EFFECT_CSV_OUTPUT_PATH, FileAccess.WRITE)
	# Write the headers
	var header_str := "Barrel ID, Barrel Name, Barrel Description"
	output_file.store_line(header_str)
	# Write each resource as a line
	for value in effects_dict.values():
		var effect_properties := PackedStringArray([
			str(value.barrel_id),
			str(value.barrel_name), 
			'"' + str(strip_bbcode(value.barrel_desc)) + '"'
		])
		var effect_str := ",".join(effect_properties)
		output_file.store_line(effect_str)


func strip_bbcode(source:String) -> String:
	var regex = RegEx.new()
	regex.compile("\\[.+?\\]")
	return regex.sub(source, "", true)


func _run() -> void:
	var effects_dict := collect_current_effect_resources()
	create_csv(effects_dict)
