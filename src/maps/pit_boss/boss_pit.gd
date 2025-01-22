extends Node3D

@export var bgm: AudioStream

@onready var func_godot_parent: FuncGodotMap = $FuncGodotMap
@onready var boss_trigger: Area3D = $BossTrigger

@export var pit_boss: BossPit
@export var surveillance_boss: BossSurveillance
@onready var player: Player = find_children("*", "Player").front()
@onready var elevator_doors: ElevatorDoors = find_children("*", "ElevatorDoors").front()
@onready var turret_spawns: Array = find_children("*", "TurretSpawnPoint")

var nav_region: NavigationRegion3D
var cover_spawn_points: Array = []
var cover_objects: Array = []


func _ready() -> void:
	#boss.health_component.died.connect(_on_boss_defeated)
	surveillance_boss.turret_spawns = turret_spawns
	#player.health_component.died.connect(_on_player_death)
	
	if GameManager.cached_player_pos_relative_to_elevator_doors:
		var player_start_pos: Vector3 = elevator_doors.global_position - GameManager.cached_player_pos_relative_to_elevator_doors
		player.global_position = player_start_pos
		player.rotation = GameManager.cached_player_rotation
		player.player_camera.rotation = GameManager.cached_camera_rotation
	
	elevator_doors.open()
	
	await get_tree().physics_frame
	generate_navigation()


func generate_navigation() -> void:
	nav_region = NavigationRegion3D.new()
	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_radius = 1.2
	#nav_mesh.agent_height = 1.0
	nav_region.navigation_mesh = nav_mesh
	
	func_godot_parent.add_child(nav_region)
	func_godot_parent.move_child(nav_region, 0)
	
	var worldspawn_mesh: StaticBody3D = func_godot_parent.find_child("entity_0_worldspawn")
	func_godot_parent.remove_child(worldspawn_mesh)
	nav_region.add_child(worldspawn_mesh)
	nav_region.move_child(worldspawn_mesh, 0)
	
	cover_spawn_points = find_children("*", "CoverSpawnPoint")
	
	nav_region.bake_navigation_mesh()


func spawn_cover() -> void:
	for object in cover_spawn_points:
		var cover = object.spawn_cover()
		object.remove_child(cover)
		nav_region.add_child(cover)
		cover.global_position = object.global_position
		cover.show_cover()
		cover.cover_destroyed.connect(nav_region.bake_navigation_mesh)
		cover.cover_destroyed.connect(_on_cover_destroyed)
		cover_objects.append(cover)


func _on_cover_destroyed(cover: Cover) -> void:
	cover_objects.erase(cover)
	if cover_objects.size() < cover_spawn_points.size() / 2:
		for object in cover_objects:
			cover.cover_destroyed.disconnect(_on_cover_destroyed)
			object.destroy()
		await get_tree().create_timer(0.2).timeout
		spawn_cover()


func _on_boss_trigger_body_entered(body: Node3D) -> void:
	if body is Player:
		spawn_cover()
		surveillance_boss.activate()
		pit_boss.activate()
		boss_trigger.queue_free()
