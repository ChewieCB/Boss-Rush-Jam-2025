extends BossCore
class_name ChipBossSubStack

@export_group("Movement")
@export var DESIRED_DISTANCE: float = 20.0
@export var desired_distance: float = DESIRED_DISTANCE
@export_subgroup("Orbiting Movement")
@export var angle_speed: float = 1.0 # radians/second
@export var orbit_angle: float = 0.0 # track this over time
@export var orbit_radius: float = 40.0

@export_group("Attacks")
@export_subgroup("Small Blind Burst")
@export var chip_projectile: PackedScene
@export var chip_shots_per_burst: int = 4
@export var num_bursts: int = 1
@export var delay_between_burst: float = 0.6
# SFX
@export var sfx_chip_shot: Array[AudioStream]

@onready var projectile_marker_pivot: Node3D = $MarkerPivot
@onready var projectile_spawn_marker: Marker3D = $MarkerPivot/Marker3D

var group_size: int = 1
var group_idx: int = 0

var nav_map_rid: RID
var nav_agent_rid: RID


func _ready() -> void:
	nav_map_rid = get_world_3d().get_navigation_map()
	nav_agent_rid = NavigationServer3D.agent_create()
	NavigationServer3D.agent_set_map(nav_agent_rid, nav_map_rid)


#func _physics_process(delta: float) -> void:
	#orbit_target_in_group(delta)


func orbit_target_in_group(delta: float) -> void:
	orbit_angle += angle_speed * delta
	# Modify the orbit angle based on how many enemies are orbiting in the group
	# so we have evenly spaced enemy orbits
	var angle_offset = (2 * PI) / group_size * (group_idx + 1)
	var current_angle = orbit_angle + angle_offset
	# offset in XZ-plane
	var offset_x = cos(current_angle) * desired_distance
	var offset_z = sin(current_angle) * desired_distance
	var orbit_pos = target.global_position + Vector3(offset_x, 0, offset_z)
	# Pathfind to orbit_pos
	navigation_component.set_nav_target_position(orbit_pos)


## SMALL BLIND PROJECTILES

func _on_small_blind_targeting_state_entered() -> void:
	debug_state_label.text = "Small Blind Burst | Targeting"
	
	state_chart.send_event("start_moving")
	state_chart.send_event("attack_buildup")
	await get_tree().create_timer(0.8).timeout
	state_chart.send_event("start_shooting")


func _on_small_blind_targeting_state_physics_processing(delta: float) -> void:
	orbit_target_in_group(delta)


func _on_small_blind_shooting_state_entered() -> void:
	debug_state_label.text = "Small Blind Burst | Shooting"
	
	state_chart.send_event("attack_telegraph")
	await get_tree().create_timer(telegraph_time).timeout
	state_chart.send_event("attack_start")
	
	for i in num_bursts:
		for j in chip_shots_per_burst:
			await get_tree().create_timer(delay_per_projectile).timeout
			fire_projectile(chip_projectile)
		await get_tree().create_timer(delay_between_burst).timeout
	
	state_chart.send_event("stop_shooting")


func _on_small_blind_shooting_state_physics_processing(delta: float) -> void:
	orbit_target_in_group(delta)


func fire_projectile(_projectile_prefab: PackedScene) -> BaseProjectile:
	var _sfx_player = get_available_sfx_player()
	if not _sfx_player:
		# TODO - error handling
		pass
	_sfx_player.stream = sfx_chip_shot.pick_random()
	_sfx_player.play()
	var projectile := _projectile_prefab.instantiate()
	get_tree().root.get_child(2).add_child(projectile)
	projectile.global_position = projectile_spawn_marker.global_position
	projectile.look_at(target.global_position, Vector3.UP)
	return projectile


func _on_small_blind_recover_state_entered() -> void:
	debug_state_label.text = "Small Blind Burst | Recovering"
	
	state_chart.send_event("attack_end")
	await get_tree().create_timer(attack_recovery_time).timeout
	state_chart.send_event("cooldown_end")
	
	select_attack()
	state_chart.send_event("end_recovery")
