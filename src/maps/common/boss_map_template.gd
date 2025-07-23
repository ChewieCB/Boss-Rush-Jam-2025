extends Node3D
class_name BossMap

@export var bgm: AudioStream

## World Geometry & Navigation
@onready var func_godot_parent: FuncGodotMap = $FuncGodotMap
@onready var worldspawn_mesh: StaticBody3D = func_godot_parent.find_child("entity_0_worldspawn")
var nav_region: NavigationRegion3D
@export var nav_parent: Node3D
@export var floor_parent: Node3D
@export var floor_mesh: MeshInstance3D

@export_group("Actors")
@onready var boss: BossCore = find_children("*", "BossCore").front()
@onready var player: Player = find_children("*", "Player").front()
@onready var elevator_doors: ElevatorDoors = find_children("*", "ElevatorDoors").front()

@export_group("UI")
@export var win_subtext: Array[String] = [""]
@export var lose_tips: Array[String] = [""]
@onready var win_ui: Control = $UI/BossDefeatedUI

@onready var directional_light: DirectionalLight3D = $DirectionalLight3D

@onready var boss_trigger: Area3D = $BossTriggerVolume
@onready var spin_trigger: Area3D = $SpinTriggerVolume

var chips_dropped: int = 0
var chip_value_collected: int = 0


func _ready() -> void:
	if OS.is_debug_build():
		print("\n[Export Variable Debug] Checking for unset exports in ", self.name)
		var export_info = self.get_property_list()
		for prop in export_info:
			if "usage" in prop and (prop.usage & PROPERTY_USAGE_EDITOR) and prop.name != "script":
				var value = self.get(prop.name)
				if value == null or (value is Resource and not is_instance_valid(value)):
					print("!! Unset or invalid export: ", prop.name)
				else:
					print(prop.name, " → ", value)
	
	if bgm:
		SoundManager.play_music(bgm, 0.5, "BGM")
	
	# Pre-load the lobby scene for faster level transitions
	LoadingHandler.current_scene_path = "res://src/maps/lobby/Lobby.tscn"
	
	if not boss:
		push_error("No boss defined for map.")
	else:
		if not boss.is_node_ready():
			await boss.ready
		boss.died.connect(_on_boss_died)
		boss.defeated.connect(_on_boss_defeated)
		boss.chip_dropped.connect(_on_chip_dropped)
	
	player.health_component.died.connect(_on_player_death)
	# Sync the player's location in the elevator from the lobby
	if GameManager.cached_player_pos_relative_to_elevator_doors:
		var player_start_pos: Vector3 = elevator_doors.global_position - GameManager.cached_player_pos_relative_to_elevator_doors
		player.global_position = player_start_pos
		player.rotation = GameManager.cached_player_rotation
		player.player_camera.rotation = GameManager.cached_camera_rotation
	
	player.stat_ui.show_luck_ui()
	
	await get_tree().physics_frame
	generate_navigation()
	
	if elevator_doors:
		elevator_doors.open()


func generate_navigation() -> void:
	if not nav_parent or not floor_mesh:
		push_warning("Navmesh nodes not configured, navigation generation aborted")
		return
	
	nav_region = NavigationRegion3D.new()
	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_radius = 1.2
	#nav_mesh.agent_height = 1.0
	nav_region.navigation_mesh = nav_mesh
	
	nav_parent.add_child(nav_region)
	nav_parent.move_child(nav_region, 0)
	
	floor_parent.remove_child(floor_mesh)
	nav_region.add_child(floor_mesh)
	nav_region.move_child(floor_mesh, 0)
	
	_rebake_nav()
	# Switch the parse type to colliders after the initial bake 
	# to reduce performance impact of runtime rebaking
	#
	# FIXME - this wipes out the nav mesh on rebaking,
	# have a proper refactor of the cover navigation 
	# to accomodate this gemoetry type parsing.
	#nav_mesh.geometry_parsed_geometry_type = NavigationMesh.ParsedGeometryType.PARSED_GEOMETRY_STATIC_COLLIDERS


func _rebake_nav() -> void:
	if nav_region.is_baking():
		await nav_region.bake_finished
	nav_region.bake_navigation_mesh()


func show_end_panel() -> void:
	LuckHandler.enabled = false
	win_ui.visible = true
	var tween = get_tree().create_tween()
	tween.tween_property(win_ui, "modulate", Color(Color.WHITE, 1.0), 1.0)
	await tween.finished
	await get_tree().create_timer(2.5).timeout
	tween = get_tree().create_tween()
	tween.tween_property(win_ui, "modulate", Color(Color.WHITE, 0.0), 1.0)
	await tween.finished
	
	LoadingHandler.start_loading("Lobby")


func collect_all_chips() -> void:
	var target_pos = player.global_position
	for chip in get_tree().get_nodes_in_group("currency_chips"):
		var chip_move_time: float = chip.global_position.distance_to(target_pos) / 70.0
		var chip_tween: Tween = get_tree().create_tween()
		chip_tween.tween_property(chip, "global_position", player.global_position, chip_move_time).set_ease(Tween.EASE_IN)


func _on_boss_died(boss: BossCore = boss) -> void:
	var tween = self.create_tween()
	tween.tween_property(directional_light, "light_energy", 0, 1)


func _on_boss_defeated(boss: BossCore) -> void:
	collect_all_chips()
	win_ui.win("Floor Cleared", win_subtext.pick_random())
	print("Chips dropped: %s | Total chip value: %s" % [chips_dropped, chip_value_collected])
	
	if not boss.boss_id in GameManager.bosses_defeated:
		GameManager.bosses_defeated.append(boss.boss_id)
		print(GameManager.bosses_defeated)
		GameManager.all_bosses_defeated = GameManager.bosses_defeated.size() == BossCore.BossIdEnum.size() - 1

	show_end_panel()


func _on_player_death() -> void:
	win_ui.lose(lose_tips.pick_random())
	show_end_panel()


func _on_boss_trigger_volume_body_entered(_body: Node3D) -> void:
	print_debug("Boss trigger volume activated")
	boss.activate()
	print_debug("Boss activate method called")
	LuckHandler.enabled = true
	elevator_doors.close()
	print_debug("Elevator doors closed, freeing trigger volume")
	boss_trigger.queue_free()


func _on_spin_trigger_body_entered(body: Node3D) -> void:
	spin_trigger.monitoring = false
	spin_trigger.queue_free()
	body.current_gun.spin_all_barrels()


# DEBUG to track chip drop rates
func _on_chip_dropped(value: int) -> void:
	chips_dropped += 1
	chip_value_collected += value


func _on_level_select(level_path: String) -> void:
	#SFXDoorClose.play()
	ResourceLoader.load_threaded_request(level_path)
	elevator_doors.close()
	await elevator_doors.anim_player.animation_finished
	# Wait until the level has been loaded on another thread
	while ResourceLoader.load_threaded_get_status(level_path) != ResourceLoader.THREAD_LOAD_LOADED:
		pass
	# Get the player's position relative to the elevator doors
	GameManager.cached_player_pos_relative_to_elevator_doors = elevator_doors.global_position - GameManager.player.global_position
	GameManager.cached_player_rotation = GameManager.player.rotation
	GameManager.cached_camera_rotation = GameManager.player.player_camera.rotation
	var loaded_scene = ResourceLoader.load_threaded_get(level_path)
	# HACK - do this properly with dynamic loading of scenes
  
	if is_inside_tree():
		# TODO - fade this out via tween
		SoundManager.stop_music(0.5)
		var new_bgm = loaded_scene.get_state().get_node_property_value(0, 1)
		# TODO - fixme
		#if new_bgm:
			#SoundManager.play_music(new_bgm, 0.25, "BGM")
		#GameManager.is_free_reroll = false
		get_tree().change_scene_to_packed(loaded_scene)
