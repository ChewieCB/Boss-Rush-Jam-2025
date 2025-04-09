extends CharacterBody3D

# TODO - just extend boss core for this scene and disable the unnessecary parts
# better yet, make a core character class that BossCore can extend from

@export var health_component: HealthComponent
@export var navigation_component: NavigationComponent

var nav_map_rid: RID
var nav_agent_rid: RID


func _ready() -> void:
	nav_map_rid = get_world_3d().get_navigation_map()
	nav_agent_rid = NavigationServer3D.agent_create()
	NavigationServer3D.agent_set_map(nav_agent_rid, nav_map_rid)
