extends BossMap

@export var flying_nav_mesh: NavigationRegion3D
@export var tiltable_parent: Node3D
@export var tilt_particles: GPUParticles3D
@export var chip_stacks_parent: Node3D
@export var min_stack_height: float = 0.3
@export var max_stack_height: float = 1.0

@onready var tilt_grab_markers = get_tree().get_nodes_in_group("boss_tilt_grab_marker")
@onready var boss_tilt_platform_origin_marker = get_tree().get_nodes_in_group("boss_tilt_platform_origin_marker")
@onready var boss_intro_path_markers = get_tree().get_nodes_in_group("boss_intro_path_marker")
@onready var hand_spawn_marker = get_tree().get_nodes_in_group("boss_hand_spawn_marker")


func _ready() -> void:
	remove_child(tilt_particles)
	tiltable_parent.add_child(tilt_particles)
	
	boss.flying_nav = flying_nav_mesh
	boss.tilt_platform_origin_marker = boss_tilt_platform_origin_marker.front()
	boss.tilt_particles = tilt_particles
	boss.tilt_hand_markers = tilt_grab_markers
	boss.intro_path_points = boss_intro_path_markers
	boss.hand_spawn_pos = hand_spawn_marker.front()
	
	#for stack in chip_stacks_parent.get_children():
		#var _rotation: float = randf_range(0, 2*PI)
		## If minimum scale is 0.5 then minimum y value is -3.25
		#var new_y_scale: float = randf_range(min_stack_height, max_stack_height)
		#var new_y_pos: float = remap(new_y_scale, 0.5, 1.0, -3.25, 0.0)
		#var stack_mesh: MeshInstance3D = stack.get_child(0)
		#var stack_collider: CollisionShape3D = stack.get_child(1)
		#stack_mesh.scale.y = new_y_scale
		#stack_mesh.position.y = new_y_pos
		##stack_mesh.rotate_y(_rotation)
		#stack_collider.scale.y = new_y_scale
		#stack_collider.position.y = new_y_pos
		##stack_collider.rotate_y(_rotation)
	
	super()



func _on_killbox_area_body_entered(body: Node3D) -> void:
	if "health_component" in body:
		if body is Player:
			body.fall_death()
		else:
			body.health_component.damage(9999999)
	else:
		body.queue_free()
