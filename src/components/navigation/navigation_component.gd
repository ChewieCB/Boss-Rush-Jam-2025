extends BaseComponent
class_name NavigationComponent

signal pathfinding_ready
signal destination_reached

@export_category("Components")
#@export var attack_component: AttackComponent
@export var nav_agent: NavigationAgent3D
@export_category("Movement")
@export var current_speed: float = 10.0
@export var acceleration: float = 7.0
@export_category("Target Finding")
@export var follow_target: bool = true
@export var search_radius: float = 128
@export var max_intersect_results := 8
@export_category("Avoidance")
@export var avoid_radius: float = 4.0

var target: Node3D:
	set(value):
		target = value
		if target:
			set_nav_target_position(target.global_position)
		#nav_agent.set_target_position(target.global_position)
var path: PackedVector3Array
var nav_map_rid: RID
var nav_agent_rid: RID

var query: PhysicsShapeQueryParameters3D
#@onready var target_search_area: Area3D = $Area3D
@onready var entity: CharacterBody3D = get_parent()
var movement_delta: float


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	call_deferred("_wait_for_navigation_setup")


func _wait_for_navigation_setup() -> void:
	# Build the target query
	query = PhysicsShapeQueryParameters3D.new()
	query.collide_with_bodies = true
	query.collide_with_areas = true
	# TODO - make some global vars to track the collision layers
	query.collision_mask = 2 # Player
	query.shape = SphereShape3D.new()
	query.shape.radius = search_radius
	query.transform = Transform3D.IDENTITY
	
	# Setup the nav server RIDs
	nav_map_rid = entity.get_world_3d().get_navigation_map()
	nav_agent_rid = NavigationServer3D.agent_create()
	NavigationServer3D.agent_set_map(nav_agent_rid, nav_map_rid)
	NavigationServer3D.agent_set_avoidance_enabled(nav_agent_rid, true)
	NavigationServer3D.agent_set_radius(nav_agent_rid, avoid_radius)
	NavigationServer3D.agent_set_avoidance_callback(nav_agent_rid, self._on_velocity_computed)
	nav_agent.velocity_computed.connect(self._on_velocity_computed)
	#NavigationServer3D.map_changed.connect(_on_map_changed)
	
	process_mode = Node.PROCESS_MODE_INHERIT
	pathfinding_ready.emit()


func _physics_process(_delta) -> void:
	if is_enabled():
		# Do not query when the map has never synchronized and is empty.
		if NavigationServer3D.map_get_iteration_id(nav_agent.get_navigation_map()) == 0:
			return
		if nav_agent.is_navigation_finished():
			return
		
		if follow_target:
			if not target:
				return
			set_nav_target_position(target.global_position)
		var new_velocity = get_new_nav_agent_velocity()
		if nav_agent.avoidance_enabled:
			nav_agent.set_velocity(new_velocity)
		else:
			_on_velocity_computed(new_velocity)


func set_nav_target_position(pos: Vector3) -> void:
	if not enabled:
		return
	if pos != nav_agent.target_position:
		nav_agent.target_position = pos
		await nav_agent.path_changed


func get_new_nav_agent_velocity() -> Vector3:
	if nav_agent.is_navigation_finished():
		destination_reached.emit()
		return entity.global_position

	var current_agent_position: Vector3 = entity.global_position
	var next_path_position: Vector3 = nav_agent.get_next_path_position()
	var direction: Vector3 = current_agent_position.direction_to(next_path_position)
	var intended_velocity: Vector3 = direction * current_speed
	
	return intended_velocity


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if is_enabled():
		entity.velocity = safe_velocity
		entity.velocity = entity.velocity.move_toward(safe_velocity, 0.25)
		entity.move_and_slide()
