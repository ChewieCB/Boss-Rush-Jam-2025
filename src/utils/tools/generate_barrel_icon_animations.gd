@tool
extends EditorScript

const EFFECT_ICON_DIR_PATH := "res://assets/sprite/effect_icons/"
const GUN_RESOURCES_PATH := "res://src/player/gun/resources"
const BASE_ANIM_LIBRARY_PATH := GUN_RESOURCES_PATH + "/gun_base_anim_library.res"
const BASE_ICON_SPRITES_PATH := "res://src/player/gun/assets/sprite/effect_icons/%s/barrel_%s/"

var base_anim_library: AnimationLibrary


func create_animations_for_barrel_icon(barrel_idx: int, icon_id: int) -> Dictionary:
	# Build a path to the icon sprites
	var icon_sprites_path := BASE_ICON_SPRITES_PATH % [icon_id, barrel_idx + 1]
	print(icon_sprites_path)
	
	# Get the array of sprites for spin_start and spin_end for the given icon
	var spin_start_sprites: Array[CompressedTexture2D] = []
	var spin_start_dir = DirAccess.open(icon_sprites_path + "IconSpinOut/")
	for image_path in spin_start_dir.get_files():
		if image_path.ends_with(".import"):
			continue
		var full_path := icon_sprites_path + "IconSpinOut/" + image_path
		spin_start_sprites.append(load(full_path))
	
	var spin_end_sprites: Array[CompressedTexture2D] = [null]
	var spin_end_dir = DirAccess.open(icon_sprites_path + "IconSpinIn/")
	for image_path in spin_end_dir.get_files():
		if image_path.ends_with(".import"):
			continue
		var full_path := icon_sprites_path + "IconSpinIn/" + image_path
		spin_end_sprites.append(load(full_path))
	
	# Update the base animations with the new textures, 
	# appending the new animation to the output array.
	var output_anims: Dictionary = {}
	for anim_name in ["spin_start", "spin_end", "idle"]:
		# Copy the base animation to get the tracks and keyframe positions
		var base_anim: Animation = base_anim_library.get_animation("barrel_%s_%s" % [barrel_idx + 1, anim_name])
		var new_anim := Animation.new()
		# Copy the anim tracks to the new animation
		for track_idx in range(3): 
			base_anim.copy_track(track_idx, new_anim)
		
		# Determine the properties for each named animation
		var sprite_arr: Array 
		var anim_frames: int
		var effect_texture_key: int
		match anim_name:
			"spin_start":
				sprite_arr = spin_start_sprites
				anim_frames = 10
				effect_texture_key = 1
			"spin_end":
				sprite_arr = spin_end_sprites
				anim_frames = 11
				effect_texture_key = 1
			"idle":
				sprite_arr = [spin_end_sprites[-1]]
				anim_frames = 1
				effect_texture_key = 1
		
		# Update the barrel icon texture track with the new anim frames
		for i in range(anim_frames):
			new_anim.track_set_key_value(effect_texture_key, i, sprite_arr[i])
		
		output_anims[anim_name] = new_anim
	
	return output_anims


func _run() -> void:
	base_anim_library = ResourceLoader.load(BASE_ANIM_LIBRARY_PATH)
	var icon_anim_library := AnimationLibrary.new()
	print(base_anim_library.get_animation_list())
	
	var dir := DirAccess.open(EFFECT_ICON_DIR_PATH)
	var num_effect_icons: int = Array(dir.get_files()).filter(
		func(x):
			return x.get_extension() == "png"
	).size()
	print("\nEffect icons count: %s" % num_effect_icons)
	
	for i in range(-1, num_effect_icons - 1):
		for j in range(3):
			var _anims: Dictionary = create_animations_for_barrel_icon(j, i)
			for anim_name in _anims.keys():
				var _anim: Animation = _anims[anim_name]
				icon_anim_library.add_animation(
					"barrel_%s_%s_icon_%s" % [j + 1, anim_name, i], 
					_anim
				)
	print()
	print(icon_anim_library.get_animation_list().size())
	print("Saving to %s/barrel_icon_anims.tres" % [GUN_RESOURCES_PATH])
	var save_result = ResourceSaver.save(icon_anim_library, "%s/barrel_icon_anims.tres" % [GUN_RESOURCES_PATH])
