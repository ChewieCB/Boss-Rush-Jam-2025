extends BossCore
class_name Chipling

@export var spark_scene: PackedScene

@export_group("Movement")
@export var DESIRED_DISTANCE: float = 20.0
@export var desired_distance: float = DESIRED_DISTANCE
@export var wave_amplitude: float = 7.0
@export var wave_frequency: float = 5.0
@export var time_elapsed: float = 0.0
@export var idle_radius := 1.5
var idle_time := 0.0
var center_pos: Vector3
@export_subgroup("Orbiting Movement")
@export var angle_speed: float = 1.0 # radians/second
@export var orbit_angle: float = 0.0 # track this over time
@export var orbit_radius: float = 40.0
@export_subgroup("Wandering Movement")
@export var wander_waypoints: Array[Marker3D] = []
@export var max_wander_distance: float = 20.0
@export var max_waypoint_jitter_radius: float = 4.0
@export var wander_delay_min: float = 0.5
@export var wander_delay_max: float = 2.3
@export var wander_radius: float = 30.0
@export var wander_timeout: float = 1.2
@onready var wander_idle_timer: Timer = $IdleTimer
@onready var wander_delay_timer: Timer = $WanderTimer

var nav_map_rid: RID
var nav_agent_rid: RID


func _ready() -> void:
	GRAVITY = 0
	super()
	health_component.health_changed.connect(_on_health_changed)
	
	nav_map_rid = get_world_3d().get_navigation_map()
	nav_agent_rid = NavigationServer3D.agent_create()
	NavigationServer3D.agent_set_map(nav_agent_rid, nav_map_rid)


func _on_died() -> void:
	died.emit()
	health_component.show_damage_text = false
	state_chart.send_event("death")
	state_chart.send_event("stop_moving")
	state_chart.send_event("deactivate")
	await death_anim_finished


func _on_passive_idle_state_entered() -> void:
	navigation_component.enabled = false
	var idle_time: float = randf_range(wander_delay_min, wander_delay_max)
	wander_delay_timer.start(idle_time)


func _on_passive_wander_state_entered() -> void:
	navigation_component.follow_target = false
	navigation_component.enabled = true
	# Pick a random location to wander to
	# TODO - replace this with a set of manual waypoints, 
	# this way we can region lock them to areas of the map
	var nearby_wander_points = wander_waypoints.filter(
		func(point):
			return point.global_position.distance_to(self.global_position) <= max_wander_distance
	)
	var new_wander_point: Vector3 = nearby_wander_points.pick_random().global_position
	# Jitter that position a bit to make it less uniform
	var offset_vector := Vector3.FORWARD * randf_range(0, max_waypoint_jitter_radius)
	var jittered_point: Vector3 = new_wander_point + offset_vector.rotated(
		Vector3.UP, randf_range(0, 2 * PI)
	)
	draw_debug_sphere(new_wander_point, 0.5, Color.PURPLE)
	draw_debug_sphere(jittered_point, 0.5, Color.MAGENTA)
	navigation_component.set_nav_target_position(jittered_point)
	wander_idle_timer.start(wander_timeout)


func _on_passive_wander_state_physics_processing(delta: float) -> void:
	pass # Replace with function body.


func _on_wander_timer_timeout() -> void:
	wander_idle_timer.stop()
	state_chart.send_event("start_wander")


func _on_wander_idle_timer_timeout() -> void:
	wander_delay_timer.stop()
	state_chart.send_event("end_wander")
