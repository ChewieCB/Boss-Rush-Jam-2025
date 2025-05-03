extends BossMap

@export var active_bgm: AudioStream

#
@onready var chiptopede_spawns: Array[Node] = get_tree().get_nodes_in_group("boss_worm_spawn_marker")
@onready var chiptopede_snake_spawns: Array[Node] = get_tree().get_nodes_in_group("boss_snake_spawn_marker")
@onready var chiptopede_snake_path_points: Array[Node] = get_tree().get_nodes_in_group("boss_snake_path_marker")
@onready var chiptopede_shoot_spawns: Array[Node] = get_tree().get_nodes_in_group("boss_shoot_spawn_marker")

# Flooding/Draining levels
@export var lower_water_level: float = -0.1
@export var upper_water_level: float = 1.3
@export var platform_level: float = 2.0
@onready var waterfalls: Node3D = $Waterfalls
@onready var water_surface: MeshInstance3D = $WaterSurfaceMesh
@onready var rising_platforms: Array[Node] = get_tree().get_nodes_in_group("rising_platforms")

# Water damage
@onready var water_damage_timer: Timer = $WaterDamageTimer
@export var water_damage_tick: float = 0.6
@export var water_damage_amount: float = 5.0

@export var breakable_floor: Node3D


func _ready() -> void:
	boss.flood_chamber.connect(raise_water)
	boss.drain_chamber.connect(lower_water)
	boss.break_floor.connect(break_floor)
	
	
	boss.chiptopede_spawns = chiptopede_spawns
	boss.chiptopede_snake_spawns = chiptopede_snake_spawns
	boss.chiptopede_snake_path_points = chiptopede_snake_path_points
	boss.chiptopede_shoot_spawns = chiptopede_shoot_spawns

	waterfalls.visible = false
	water_surface.global_position.y = lower_water_level

	super()


#func _input(event: InputEvent) -> void:
	#if event.is_action_pressed("input_1"):
		#break_floor()
		#raise_water()
	#elif event.is_action_pressed("input_2"):
		#lower_water()


func break_floor() -> void:
	water_surface.visible = true
	#lower_water()
	water_surface.global_position.y = -19.3
	if breakable_floor:
		breakable_floor.queue_free()
	for platform in rising_platforms:
		platform.queue_free()


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


func _rebake_nav() -> void:
	if nav_region.is_baking():
		await nav_region.bake_finished
	nav_region.bake_navigation_mesh()


func raise_water() -> void:
	waterfalls.visible = true
	var water_tween: Tween = get_tree().create_tween()
	water_tween.tween_property(water_surface, "global_position:y", upper_water_level, 1.4)
	for platform in rising_platforms:
		platform.raise(platform_level, 1.4)

	await water_tween.finished

	boss.state_chart.send_event("start_aoe_attack")


func lower_water() -> void:
	waterfalls.visible = false
	var water_tween: Tween = get_tree().create_tween()
	water_tween.tween_property(water_surface, "global_position:y", lower_water_level, 1.4)
	for platform in rising_platforms:
		platform.lower(1.4)

	await water_tween.finished

	boss.state_chart.send_event("end_aoe_attack")


func _on_water_damage_area_body_entered(body: Node3D) -> void:
	return
	# TODO - add drunk effect instead of damage
	if body is Player:
		player.health_component.damage(water_damage_amount)
		water_damage_timer.start(water_damage_tick)


func _on_water_damage_area_body_exited(body: Node3D) -> void:
	if body is Player:
		water_damage_timer.stop()


func _on_water_damage_timer_timeout() -> void:
	player.health_component.damage(water_damage_amount)
