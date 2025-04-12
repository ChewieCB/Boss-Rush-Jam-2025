extends CharacterBody3D

# TODO - just extend boss core for this scene and disable the unnessecary parts
# better yet, make a core character class that BossCore can extend from

@export var health_component: HealthComponent
@export var navigation_component: NavigationComponent

@export_group("Movement")
@export var DESIRED_DISTANCE: float = 10.0
@export var desired_distance: float = DESIRED_DISTANCE
@export_subgroup("Orbiting Movement")
@export var angle_speed: float = 1.0 # radians/second
@export var orbit_angle: float = 0.0 # track this over time
@export var orbit_radius: float = 20.0

var group_size: int = 1
var group_idx: int = 0

var nav_map_rid: RID
var nav_agent_rid: RID

@export var target: Node3D:
	set(value):
		target = value
		if target:
			if not target.is_node_ready():
				await target.ready
			navigation_component.target = target
var cached_target: Node3D


func _ready() -> void:
	nav_map_rid = get_world_3d().get_navigation_map()
	nav_agent_rid = NavigationServer3D.agent_create()
	NavigationServer3D.agent_set_map(nav_agent_rid, nav_map_rid)


func _physics_process(delta: float) -> void:
	orbit_target(delta)


# TODO - move core movement functions to a shared enemy movement library
func orbit_target(delta: float) -> void:
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


func orbit_target_in_group(delta: float, group_size: int, group_idx: int) -> void:
	orbit_angle += angle_speed * delta
	# offset in XZ-plane
	var offset_x = cos(orbit_angle) * desired_distance
	var offset_z = sin(orbit_angle) * desired_distance
	var orbit_pos = target.global_position + Vector3(offset_x, 0, offset_z)
	# Pathfind to orbit_pos
	navigation_component.set_nav_target_position(orbit_pos)


func orbit_towards_target(
	delta: float, approach_speed: float = 1.0, min_radius: float = 10.0
) -> void:
	orbit_angle += angle_speed * delta
	
	orbit_radius -= approach_speed * delta
	if min_radius:
		orbit_radius = max(orbit_radius, min_radius)
	
	# offset in XZ-plane
	var offset_x = cos(orbit_angle) * orbit_radius
	var offset_z = sin(orbit_angle) * orbit_radius
	var orbit_pos = target.global_position + Vector3(offset_x, 0, offset_z)
	# Pathfind to orbit_pos
	navigation_component.set_nav_target_position(orbit_pos)
