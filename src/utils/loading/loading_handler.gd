extends Node

signal materials_compiled
signal icon_anims_compiled
signal scene_path_loaded(scene_path: String)
signal loading_finished(scene: PackedScene)
signal loaded_seamless


enum LEVELS {
	TUTORIAL,
	TUTORIAL_BOSS_ONLY,
	BACKROOM,
	LOBBY,
	SLOTS,
	ROULETTE,
	BARTENDER,
	PIT,
	CHIPS,
	BLACKJACK,
	CROONER
}

const level_paths: Array[String] = [
	"res://src/maps/tutorial/TutorialBossNew.tscn",
	"res://src/maps/tutorial/TutorialBossOnly.tscn",
	"res://src/maps/backroom/Backroom.tscn",
	"res://src/maps/lobby/Lobby.tscn",
	"res://src/maps/slots_boss/BossMapSlots.tscn",
	"res://src/maps/roulette_boss/BossMapRoulette.tscn",
	"res://src/maps/bartender_boss/BossMapBartender.tscn",
	"res://src/maps/pit_boss/BossMapPit.tscn",
	"res://src/maps/chip_boss/BossMapChip.tscn",
	"res://src/maps/blackjack_boss/BossMapBlackjack.tscn",
	"res://src/maps/crooner_boss/BossMapCrooner.tscn",
]


# Loading
var current_scene_path: String:
	set(value):
		current_scene_path = value
		ResourceLoader.load_threaded_request(current_scene_path)
var can_transition: bool = false
var skip_equip_anim: bool = false

# Shader pre-compilation
const PRECOMPILE_CONFIG_PATH: String = "res://config/precompile_list.config"
const IGNORED_PATH_EXTENSIONS: Array[String] = [
	"mp3", "wav",
	"png", "jpg", "svg",
]
@export var debug_skip_pre_compile: bool = false
@export var max_materials_compiled_per_frame: int = 8
var scenes_to_compile: Array = []
var compiling_materials_count: int = 0
var compiled_material_paths := []
var is_compiling: bool = false
var is_materials_compiled: bool = false

@onready var compile_parent = $CompileParent


func collect_scenes_to_compile() -> void:
	var file = FileAccess.open(PRECOMPILE_CONFIG_PATH, FileAccess.READ)
	var path = file.get_line()
	while path != "":
		scenes_to_compile.append(path)
		path = file.get_line()


func initial_load() -> void:
	# Pre-cache files we know contain materials to load
	if OS.is_debug_build() and not debug_skip_pre_compile:
		await Engine.get_main_loop().process_frame
		ScreenTransition.set_loading_detail_text("Parsing scene paths to compile")
		parse_scene_paths_to_compile()
	await Engine.get_main_loop().process_frame
	ScreenTransition.set_loading_detail_text("Collecting scenes to compile")
	collect_scenes_to_compile()
	await Engine.get_main_loop().process_frame
	ScreenTransition.set_loading_detail_text("Compiling materials")
	is_compiling = true


func start_loading(scene_path: String, scene_name: String = "", transition_out: bool = true) -> void:
	ScreenTransition.set_loading_detail_text(scene_name)
	find_and_load_scene_bgm(scene_name)
	if transition_out:
		ScreenTransition.transition_out()
		await ScreenTransition.transition_finished
	
	current_scene_path = scene_path
	
	# Save the game when loading a new scene
	if GameManager.chosen_slot_id != -1:
		GameManager.update_total_playtime()
		await SaveManager.save_game(GameManager.chosen_slot_id)
	
	if not is_materials_compiled:
		initial_load()
		await materials_compiled
	
	#await Engine.get_main_loop().process_frame


func load_scene_transition() -> void:
	if not is_materials_compiled:
		await materials_compiled
	
	can_transition = true
	await scene_path_loaded
	
	var packed_scene = ResourceLoader.load_threaded_get(current_scene_path)
	_load_scene(packed_scene)
	ScreenTransition.set_loading_visible(false)
	ScreenTransition.transition_in()
	await ScreenTransition.transition_finished


func find_and_load_scene_bgm(scene_name: String = "") -> void:
	if scene_name == "":
		return

	var music_state = ""
	match scene_name:
		"Main Menu":
			music_state = "Menu"
		"Lobby":
			music_state = "Lobby"
		"Backroom":
			music_state = "Backroom"
		"Tutorial":
			music_state = "TutorialStart"

	if music_state != "":
		GameManager.change_fmod_bgm_music_state(music_state)

func load_scene_seamless() -> void:
	if not is_materials_compiled:
		await materials_compiled
	
	can_transition = true
	await scene_path_loaded
	
	var packed_scene = ResourceLoader.load_threaded_get(current_scene_path)
	_load_scene(packed_scene)
	await loading_finished
	loaded_seamless.emit()


func _load_scene(packed_scene: PackedScene) -> void:
	can_transition = false
	get_tree().change_scene_to_packed(packed_scene)
	await Engine.get_main_loop().process_frame
	loading_finished.emit(packed_scene)


func _process(_delta: float) -> void:
	if current_scene_path:
		var level_progress = []
		ResourceLoader.load_threaded_get_status(current_scene_path, level_progress)
		
		ScreenTransition.progress_bar.value = level_progress[0] * 100
		
		if level_progress[0] == 1 and can_transition:
			scene_path_loaded.emit(current_scene_path)


func _physics_process(_delta: float) -> void:
	if is_compiling:
		compile_materials()


func parse_scene_paths_to_compile() -> void:
	var scene_path_list := []
	var regex_pattern := "(sub_resource|ext_resource) type=\"(ParticleProcessMaterial|ShaderMaterial|Material|CanvasItemMaterial|StandardMaterial3D)\""
	var regex = RegEx.new()
	regex.compile(regex_pattern)

	var instantiation_list := []
	var filepaths = get_filepaths_from_nested_directory("res://src", true)
	for filepath in filepaths:
		if filepath.get_extension() in IGNORED_PATH_EXTENSIONS:
			continue

		var file = FileAccess.open(filepath, FileAccess.READ)
		if file == null:
			continue
		var text = file.get_as_text()
		
		var regex_match = regex.search(text)
		if regex_match:
			instantiation_list.append(filepath)

	for scene_path in instantiation_list:
		ResourceLoader.load(scene_path)
		scene_path_list.append(scene_path)

	var save_file = FileAccess.open(PRECOMPILE_CONFIG_PATH, FileAccess.WRITE)
	for path in instantiation_list:
		save_file.store_line(path)


# TODO - move this to a utility script
func get_filepaths_from_nested_directory(dir_path: String, incl_files_from_given_dir: bool = true) -> Array:
	var files = []
	var item
	var item_path

	var dir := DirAccess.open(dir_path)
	if dir == null:
		printerr("Could not open folder", dir_path)
		return files

	dir.list_dir_begin()
	item = dir.get_next()
	while item != "":
		item_path = dir_path + "/" + item
		if dir.dir_exists(item_path):
			files += (get_filepaths_from_nested_directory(item_path, true))
		if dir.file_exists(item_path) and incl_files_from_given_dir:
			files.append(item_path)
		item = dir.get_next()
	dir.list_dir_end()

	return files


func compile_materials() -> void:
	var to_process: Array = scenes_to_compile.slice(0, max_materials_compiled_per_frame)
	scenes_to_compile = scenes_to_compile.slice(max_materials_compiled_per_frame)
	
	for scene_path in to_process:
		_compile_scene(scene_path)

	if scenes_to_compile.is_empty() and compiling_materials_count == 0:
		print("All scenes compiled.")
		is_materials_compiled = true
		is_compiling = false
		ScreenTransition.set_loading_detail_text("Materials compiled")
		materials_compiled.emit()


func _compile_scene(scene_path: String) -> void:
	print("Precompile resources in %s" % scene_path)
	var scene_resource := ResourceLoader.load(scene_path)
	if not scene_resource:
		return
	
	if scene_resource is PackedScene:
		var scene = scene_resource.instantiate()
		_compile_node_recursive(scene)
		
		# Special case: Trail3D assigns material_override at runtime
		for trail in scene.find_children("*", "MeshInstance3D", true):
			if trail.get_script() and trail.get_script().resource_path.contains("Trail3D"):
				if trail.material_override:
					_compile_material_resource(trail.material_override)
		
		scene.queue_free()

	elif scene_resource is Material:
		_compile_material_resource(scene_resource)


func _compile_node_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		if mesh_inst.mesh:
			for surface_idx in mesh_inst.mesh.get_surface_count():
				var mat = mesh_inst.mesh.surface_get_material(surface_idx)
				if mat:
					_compile_material_resource(mat)
			for surface_idx in mesh_inst.get_surface_override_material_count():
				var mat = mesh_inst.get_surface_override_material(surface_idx)
				if mat:
					_compile_material_resource(mat)
				
	elif node is GPUParticles3D:
		if node.process_material:
			_compile_particles_node(node)
	
	elif node.get("material") != null:
		_compile_material_node(node)
	
	for child in node.get_children():
		_compile_node_recursive(child)


func _compile_material_resource(mat: Material) -> void:
	var path := mat.resource_path
	if path in compiled_material_paths:
		print("Found %s in cache, skipping." % path)
		return

	compiling_materials_count += 1
	print("Caching material %s" % mat)

	var node = MeshInstance3D.new()
	node.mesh = QuadMesh.new()
	node.set_surface_override_material(0, mat)
	#node.mesh.material = mat
	compile_parent.add_child(node)

	if path:
		compiled_material_paths.append(path)
		print("Caching %s" % path)
	
	# Main pass
	await RenderingServer.frame_post_draw
	# Depth pre-pass
	await RenderingServer.frame_post_draw
	
	compiling_materials_count -= 1
	if is_instance_valid(node):
		node.queue_free()


func _compile_material_node(child: Node) -> void:
	if child.material.resource_path in compiled_material_paths:
		print("Found %s in cache, skipping." % child.material.resource_path)
		return

	compiling_materials_count += 1
	print("Caching material from %s" % child.name)

	var node = MeshInstance3D.new()
	node.mesh = QuadMesh.new()
	node.mesh.material = child.material
	compile_parent.add_child(node)

	if child.material.resource_path:
		compiled_material_paths.append(child.material.resource_path)
		print("Caching %s" % child.material.resource_path)

	compiling_materials_count -= 1
	if is_instance_valid(node):
		node.queue_free()


func _compile_particles_node(child: GPUParticles3D) -> void:
	if child.process_material.resource_path in compiled_material_paths:
		print("Found %s in cache, skipping." % child.process_material.resource_path)
		return

	compiling_materials_count += 1
	print("Caching material from %s" % child.name)

	var particles = GPUParticles3D.new()
	particles.process_material = child.process_material
	particles.emitting = true
	compile_parent.add_child(particles)

	if child.process_material.resource_path:
		compiled_material_paths.append(child.process_material.resource_path)
		print("Caching %s" % [child.process_material.resource_path])

	await get_tree().create_timer(0.5).timeout

	compiling_materials_count -= 1
	if is_instance_valid(particles):
		particles.queue_free()
