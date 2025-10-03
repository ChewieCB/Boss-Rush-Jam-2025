@tool
extends EditorScript

#var debug_barrel_scene_template
#var debug_barrel_resource_template
const debug_barrel_scene_template_path: String = "res://src/player/barrel/resource/debug_single_effects/prefabs/_DebugBarrelTemplate.tscn"
const debug_barrel_resource_template_path: String = "res://src/player/barrel/resource/debug_single_effects/_DebugBarrelResourceTemplate.tres"

const barrel_path: String = "res://src/player/barrel/"
const barrel_resource_path: String = "res://src/player/barrel/resource/"
const effect_icon_dir: String = "res://assets/sprite/effect_icons/"
const debug_barrel_prefab_dir: String = "res://src/player/barrel/resource/debug_single_effects/prefabs/"
const debug_barrel_resource_dir: String = "res://src/player/barrel/resource/debug_single_effects/"


func _run() -> void:
	# Get templates
	var debug_barrel_scene_template = load(debug_barrel_scene_template_path)
	var debug_barrel_resource_template = load(debug_barrel_resource_template_path)
	
	# Get all barrel scene file names src/player/barrel/resource
	var excluded_scenes = ["CommonBarrelComponent.tscn", "PlaceholderBarrelA.tscn", "ProjectileCountBarrel.tscn", "TestBarrel.tscn"]
	var barrel_scenes = Array(DirAccess.open(barrel_path).get_files()).filter(
		func(x): 
			return x.ends_with(".tscn") and not x in excluded_scenes
	)
	
	for file in barrel_scenes:
		var barrel = load("%s%s" % [barrel_path, file])
		# Get the individual effects for each barrel
		var effects = barrel.instantiate().get_node("EffectContainer").get_children()
		for effect in effects:
			# Cache the name and icon ID for the individual effect
			var effect_name: String = effect.get_name()
			var icon_id: int = effect.icon_id
			
			# Create a new debug barrel for each individual effect
			var debug_effect_scene = debug_barrel_scene_template.duplicate().instantiate()
			debug_effect_scene.name += effect_name
			var effect_container = debug_effect_scene.get_node("EffectContainer")
			
			var new_effect = effect.duplicate()
			effect_container.add_child(new_effect)
			# Need to update the owner or the effect container child nodes won't be saved to the file
			new_effect.owner = debug_effect_scene
			for child in new_effect.get_children():
				child.owner = debug_effect_scene
			
			# Write this to a new scene file
			var prefab_scene := PackedScene.new()
			prefab_scene.pack(debug_effect_scene)
			ResourceSaver.save(prefab_scene, "%s%s.tscn" % [debug_barrel_prefab_dir, debug_effect_scene.name])
			
			# Create a corresponding resource for each debug barrel
			var debug_effect_resource: BarrelDataResource = debug_barrel_resource_template.duplicate()
			# TODO - properly assign this
			debug_effect_resource.barrel_id = 0
			debug_effect_resource.barrel_name = effect_name
			# Assign the effect icon as the barrel image using the ID on the original barrel
			debug_effect_resource.barrel_image = load("%s%s.png" % [effect_icon_dir, icon_id])
			debug_effect_resource.barrel_cost = 0
			# Link the debug barrel scene prefab to the resource
			debug_effect_resource.barrel_prefab = load("%s%s.tscn" % [debug_barrel_prefab_dir, debug_effect_scene.name])
			
			ResourceSaver.save(debug_effect_resource, "%sdebug_%s_barrel_data.tres" % [debug_barrel_resource_dir, effect_name.to_snake_case()])
