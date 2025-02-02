extends Node3D

@export var bgm: AudioStream

@onready var func_godot_parent: FuncGodotMap = $FuncGodotMap
@onready var worldspawn_mesh: StaticBody3D = func_godot_parent.find_child("entity_0_worldspawn")
@onready var win_ui: Control = $UI/BossDefeatedUI
@export var win_subtext: Array[String]
@export var lose_tips: Array[String]
@onready var boss_trigger: Area3D = $BossTrigger

@onready var stance_timer: Timer = $StanceTimer
@export var phase_2_stance_time: float = 14.0

@export var phase_2_health_percentage_trigger: float = 0.7
@export var phase_3_health_percentage_trigger: float = 0.35

@onready var pit_boss: BossPit = find_children("*", "BossPit").front() 
@onready var surveillance_boss: BossSurveillance = find_children("*", "BossSurveillance").front()
var dead_boss_count: int = 0

@onready var player: Player = find_children("*", "Player").front()
@onready var elevator_doors: ElevatorDoors = find_children("*", "ElevatorDoors").front()
@onready var turret_spawns: Array = find_children("*", "TurretSpawnPoint")

var nav_region: NavigationRegion3D
@export var cover_spawn_scene: PackedScene
@onready var initial_cover = find_children("*", "Cover")
var cover_objects: Array = []
var cover_spawn_points: Array = []


func _ready() -> void:
	pit_boss.health_component.health_changed.connect(_on_boss_health_changed)
	pit_boss.health_component.died.connect(_on_boss_died.bind(pit_boss))
	pit_boss.surveillance_boss = surveillance_boss
	
	surveillance_boss.health_component.health_changed.connect(_on_boss_health_changed)
	surveillance_boss.health_component.died.connect(_on_boss_died.bind(surveillance_boss))
	surveillance_boss.turret_spawns = turret_spawns
	surveillance_boss.pit_boss = pit_boss
	
	player.health_component.died.connect(_on_player_death)
	
	if GameManager.cached_player_pos_relative_to_elevator_doors:
		var player_start_pos: Vector3 = elevator_doors.global_position - GameManager.cached_player_pos_relative_to_elevator_doors
		player.global_position = player_start_pos
		player.rotation = GameManager.cached_player_rotation
		player.player_camera.rotation = GameManager.cached_camera_rotation
	
	elevator_doors.open()
	
	await get_tree().physics_frame
	generate_navigation()
	
	for cover in initial_cover:
		var new_spawn = cover_spawn_scene.instantiate()
		nav_region.add_child(new_spawn)
		new_spawn.global_transform = cover.global_transform
		new_spawn.cover_type = cover._get_class()
		new_spawn.current_cover = cover
		cover.cover_destroyed.connect(_on_cover_destroyed)
		cover_spawn_points.push_back(new_spawn)
	for cover in initial_cover:
		cover.queue_free()


func _on_player_death() -> void:
	win_ui.lose(lose_tips.pick_random())
	show_end_panel()


func _on_boss_health_changed(_new_health: float, _prev_health: float) -> void:
	var combined_current_health := pit_boss.health_component.current_health + surveillance_boss.health_component.current_health
	var combined_max_health := pit_boss.health_component.max_health + surveillance_boss.health_component.max_health 
	var combined_health_ratio := combined_current_health / combined_max_health
		
	var pit_boss_health_ratio := pit_boss.health_component.current_health / \
		pit_boss.health_component.max_health
	
	if combined_health_ratio <= phase_3_health_percentage_trigger:
		stance_timer.stop()
		pit_boss.state_chart.send_event("start_phase_3")
		surveillance_boss.state_chart.send_event("start_phase_3")
	elif pit_boss.health_component.current_health_ratio <= phase_2_health_percentage_trigger:
		if pit_boss.current_phase < 2 and surveillance_boss.current_phase < 2:
			stance_timer.stop()
			pit_boss.state_chart.send_event("start_phase_2")
			surveillance_boss.state_chart.send_event("start_phase_2")
			stance_timer.start(phase_2_stance_time + randf_range(-1.5, 1.5))


func _on_boss_died(boss: BossCore) -> void:
	dead_boss_count += 1
	
	if dead_boss_count == 2:
		boss.defeated.connect(_on_bosses_defeated)
		boss.drop_barrel()
	
	var remaining_boss: BossCore
	match boss:
		pit_boss:
			remaining_boss = surveillance_boss
		surveillance_boss:
			remaining_boss = pit_boss
	remaining_boss.state_chart.send_event("start_phase_3")


func _on_bosses_defeated(boss: BossCore) -> void:
	win_ui.win("Floor Cleared", win_subtext.pick_random())
	show_end_panel()


func show_end_panel() -> void:
	win_ui.visible = true
	var tween = get_tree().create_tween()
	tween.tween_property(win_ui, "modulate", Color(Color.WHITE, 1.0), 1.0)
	await tween.finished
	await get_tree().create_timer(5.0).timeout
	tween = get_tree().create_tween()
	tween.tween_property(win_ui, "modulate", Color(Color.WHITE, 0.0), 1.0)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://src/maps/lobby/Lobby.tscn"))


func _return_to_main() -> void:
	get_tree().change_scene_to_file("res://src/ui/temp/TempMain.tscn")


func _reload_scene() -> void:
	get_tree().reload_current_scene()


func generate_navigation() -> void:
	nav_region = NavigationRegion3D.new()
	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_radius = 1.2
	#nav_mesh.agent_height = 1.0
	nav_region.navigation_mesh = nav_mesh
	
	func_godot_parent.add_child(nav_region)
	func_godot_parent.move_child(nav_region, 0)
	
	func_godot_parent.remove_child(worldspawn_mesh)
	nav_region.add_child(worldspawn_mesh)
	nav_region.move_child(worldspawn_mesh, 0)
	
	_rebake_nav()


func spawn_cover() -> void:
	for object in cover_spawn_points:
		var cover = object.spawn_cover()
		object.remove_child(cover)
		nav_region.add_child(cover)
		cover.global_transform = object.global_transform
		cover.show_cover()
		cover.cover_destroyed.connect(_on_cover_destroyed)
		cover_objects.append(cover)
	_rebake_nav()


func _rebake_nav() -> void:
	if nav_region.is_baking():
		await nav_region.bake_finished
	nav_region.bake_navigation_mesh()


func _on_cover_destroyed(cover: Cover) -> void:
	var spawn = cover_spawn_points.filter(func(x): return x.current_cover == cover).front()
	cover_objects.erase(cover)
	_rebake_nav()
	await get_tree().create_timer(randf_range(3.0, 6.5)).timeout
	
	spawn.current_cover = null
	
	var new_cover = spawn.spawn_cover()
	spawn.remove_child(new_cover)
	nav_region.add_child(new_cover)
	new_cover.global_transform = spawn.global_transform
	new_cover.show_cover()
	new_cover.cover_destroyed.connect(_on_cover_destroyed)
	cover_objects.append(new_cover)
	
	nav_region.bake_navigation_mesh()


func _on_boss_trigger_body_entered(body: Node3D) -> void:
	if body is Player:
		spawn_cover()
		surveillance_boss.activate()
		pit_boss.activate()
		boss_trigger.queue_free()


func _on_stance_timer_timeout() -> void:
	pit_boss.toggle_stance()
	surveillance_boss.toggle_stance()
	stance_timer.start(phase_2_stance_time + randf_range(-1.5, 1.5))
