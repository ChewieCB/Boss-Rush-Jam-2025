extends BossCore
class_name Chipling

@export var spark_scene: PackedScene

@export_group("Spawning")
@export var spawn_group: int = 1
@export var respawn_time: float = 2.0
#@onready var spawn_points: Array[Node] = get_tree().get_nodes_in_group("boss_chipling_spawn_marker")
@export_group("Movement")
@export var MOVE_SPEED: float = 4.0
@onready var move_speed: float = MOVE_SPEED:
	set(value):
		move_speed = value
		navigation_component.current_speed = move_speed
@export var wave_amplitude: float = 7.0
@export var wave_frequency: float = 5.0
@export var idle_radius := 1.5
var idle_time := 0.0
var center_pos: Vector3
@export_subgroup("Wandering Movement")
@export var wander_waypoints: Array[Node] = []
@export var max_wander_distance: float = 20.0
@export var max_waypoint_jitter_radius: float = 4.0
@export var wander_delay_min: float = 1.2
@export var wander_delay_max: float = 3.6
@export var wander_radius: float = 30.0
@export var wander_timeout: float = 3.6
@onready var wander_idle_timer: Timer = $IdleTimer
@onready var wander_delay_timer: Timer = $WanderTimer
var current_wander_target: Vector3
@export_subgroup("Death Juice")
@onready var chip_particles: GPUParticles3D = $ChipDeathParticles
@export var explosion_particle_prefab: PackedScene

var nav_map_rid: RID
var nav_agent_rid: RID


func _ready() -> void:
	self.visible = false
	GRAVITY = 0
	super ()
	
	nav_map_rid = get_world_3d().get_navigation_map()
	nav_agent_rid = NavigationServer3D.agent_create()
	NavigationServer3D.agent_set_map(nav_agent_rid, nav_map_rid)


func _physics_process(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	time_elapsed += delta
	var chase_direction: Vector3 = self.global_position.direction_to(current_wander_target)
	var perpendicular: Vector3 = chase_direction.rotated(Vector3.UP, PI / 2)
	var wave_offset = perpendicular * sin(time_elapsed * wave_frequency) * wave_amplitude
	var desired_position = current_wander_target + wave_offset
	navigation_component.set_nav_target_position(desired_position)
	move_and_slide()


func spawn() -> void:
	state_chart.send_event("start_spawn")


func _on_died() -> void:
	died.emit()
	var explosion = explosion_particle_prefab.instantiate()
	add_child(explosion)
	explosion.position.y = 0.781
	sprite.visible = false
	
	health_component.show_damage_text = false
	state_chart.send_event("death")
	state_chart.send_event("stop_moving")
	state_chart.send_event("deactivate")
	await death_anim_finished
	# TODO - add some juice, make the chipling explode with chips that have trails?
	chip_particles.emitting = true
	await get_tree().create_timer(0.8).timeout
	#
	self.queue_free()


func _on_passive_idle_state_entered() -> void:
	navigation_component.enabled = false
	var wait_time: float = randf_range(wander_delay_min, wander_delay_max)
	wander_delay_timer.start(wait_time)


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
	#draw_debug_sphere(new_wander_point, 0.5, Color.PURPLE)
	#draw_debug_sphere(jittered_point, 0.5, Color.MAGENTA)
	current_wander_target = jittered_point
	#navigation_component.set_nav_target_position(jittered_point)
	wander_idle_timer.start(wander_timeout)


func _on_passive_wander_state_physics_processing(_delta: float) -> void:
	pass # Replace with function body.


func _on_wander_timer_timeout() -> void:
	wander_idle_timer.stop()
	state_chart.send_event("start_wander")


func _on_wander_idle_timer_timeout() -> void:
	wander_delay_timer.stop()
	state_chart.send_event("end_wander")


func _on_spawning_idle_state_entered() -> void:
	collider.disabled = false
	GRAVITY = 0
	state_chart.send_event("start_drop")


func _on_spawning_dropping_state_entered() -> void:
	self.visible = true
	GRAVITY = 14


func _on_spawning_dropping_state_physics_processing(_delta: float) -> void:
	if self.is_on_floor():
		# TODO - add a bit of juice, squash/stretch and dust particles here?
		state_chart.send_event("finish_spawn")
