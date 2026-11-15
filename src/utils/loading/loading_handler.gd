extends Node

signal loading_started
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
# This will be false when we first load the backroom (from main menu) and true
# after return from boss fight, to skip the fancy transition stuff
var skip_transition_in: bool = false

# Material warm-up
const WARM_FILE_EXTENSIONS: Array[String] = ["tscn", "scn", "tres", "res"]
const WARM_FRAME_BUDGET_MSEC: int = 30
const WARM_DRAW_FRAMES: int = 2 # Main pass + depth pre-pass
const WARM_PARTICLE_SECONDS: float = 0.5
# Far below every level, so the warm camera sees nothing but the warm meshes
const WARM_CAMERA_POSITION := Vector3(0.0, -5000.0, 0.0)
const IN_FRONT_OF_WARM_CAMERA := Vector3(0.0, 0.0, -2.0)
var _warmed_materials: Dictionary = {}
var _materials_being_drawn: int = 0

@onready var compile_parent: Node3D = $CompileParent


func _ready() -> void:
	compile_parent.position = WARM_CAMERA_POSITION
	compile_parent.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func start_loading(scene_path: String, scene_name: String = "", transition_out: bool = true) -> void:
	loading_started.emit()
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


func load_scene_transition() -> void:
	can_transition = true
	await scene_path_loaded
	can_transition = false

	var packed_scene = ResourceLoader.load_threaded_get(current_scene_path)
	await warm_scene_materials(current_scene_path)
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


#region Material warm-up
## Only call this while the screen is covered, it takes over the 3D camera.
func warm_scene_materials(scene_path: String) -> void:
	var gameplay_camera := get_viewport().get_camera_3d()
	var warm_camera := Camera3D.new()
	compile_parent.add_child(warm_camera)
	compile_parent.visible = true
	warm_camera.make_current()

	var resource_paths := {}
	_collect_scene_and_dependencies(scene_path, resource_paths)

	var frame_start := Time.get_ticks_msec()
	for path in resource_paths:
		_warm_resource(path)
		if Time.get_ticks_msec() - frame_start >= WARM_FRAME_BUDGET_MSEC:
			await get_tree().process_frame
			frame_start = Time.get_ticks_msec()

	while _materials_being_drawn > 0:
		await get_tree().process_frame

	_warmed_materials.clear()
	compile_parent.visible = false
	warm_camera.queue_free()
	if is_instance_valid(gameplay_camera):
		gameplay_camera.make_current()


func _collect_scene_and_dependencies(path: String, collected_paths: Dictionary) -> void:
	if collected_paths.has(path) or path.get_extension() not in WARM_FILE_EXTENSIONS:
		return
	collected_paths[path] = true

	for dependency in ResourceLoader.get_dependencies(path):
		# A dependency is either "path" or "uid::type::path"
		var dependency_path := dependency.get_slice("::", 2) if "::" in dependency else dependency
		_collect_scene_and_dependencies(dependency_path, collected_paths)


func _warm_resource(path: String) -> void:
	# Loading something that is not in memory yet would freeze the game
	if not ResourceLoader.has_cached(path):
		return

	var resource := ResourceLoader.load(path)
	if resource is PackedScene:
		var scene: Node = resource.instantiate()
		_warm_node_and_children(scene)
		scene.free()
	elif resource is Material:
		_warm_material(resource)


func _warm_node_and_children(node: Node) -> void:
	if node is GeometryInstance3D:
		_warm_material(node.material_override)

	if node is MeshInstance3D:
		_warm_mesh_materials(node.mesh)
		for surface in node.get_surface_override_material_count():
			_warm_material(node.get_surface_override_material(surface))
	elif node is GPUParticles3D:
		_warm_particles(node)
	elif node.get("material") is Material:
		_warm_material(node.material)

	for child in node.get_children():
		_warm_node_and_children(child)


func _warm_mesh_materials(mesh: Mesh) -> void:
	if mesh == null:
		return
	for surface in mesh.get_surface_count():
		_warm_material(mesh.surface_get_material(surface))


func _warm_material(material: Material) -> void:
	if material == null or _warmed_materials.has(material) or not _is_3d_material(material):
		return
	_warmed_materials[material] = true

	var quad := MeshInstance3D.new()
	quad.mesh = QuadMesh.new()
	quad.material_override = material
	quad.position = IN_FRONT_OF_WARM_CAMERA
	compile_parent.add_child(quad)

	_materials_being_drawn += 1
	for frame in WARM_DRAW_FRAMES:
		await RenderingServer.frame_post_draw
	_materials_being_drawn -= 1

	quad.queue_free()


func _is_3d_material(material: Material) -> bool:
	if material is ShaderMaterial:
		return material.shader != null and material.shader.get_mode() == Shader.MODE_SPATIAL
	return material is BaseMaterial3D


func _warm_particles(source: GPUParticles3D) -> void:
	for draw_pass in source.draw_passes:
		_warm_mesh_materials(source.get_draw_pass_mesh(draw_pass))

	var process_material := source.process_material
	if process_material == null or _warmed_materials.has(process_material):
		return
	_warmed_materials[process_material] = true

	var particles := GPUParticles3D.new()
	particles.process_material = process_material
	particles.material_override = source.material_override
	particles.draw_passes = source.draw_passes
	for draw_pass in source.draw_passes:
		particles.set_draw_pass_mesh(draw_pass, source.get_draw_pass_mesh(draw_pass))
	particles.position = IN_FRONT_OF_WARM_CAMERA
	particles.emitting = true
	compile_parent.add_child(particles)

	_materials_being_drawn += 1
	var ignore_time_scale := true
	await get_tree().create_timer(WARM_PARTICLE_SECONDS, true, false, ignore_time_scale).timeout
	_materials_being_drawn -= 1

	particles.queue_free()
#endregion
