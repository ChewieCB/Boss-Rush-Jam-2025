extends BossMap

@export var flying_nav_mesh: NavigationRegion3D
@export var tiltable_parent: Node3D
@export var tilt_particles: GPUParticles3D
@export var chip_stacks_parent: Node3D
@export var min_stack_height: float = 0.3
@export var max_stack_height: float = 1.0
@export var explosive_spawn_parent: Node3D

@onready var tilt_grab_markers = get_tree().get_nodes_in_group("boss_tilt_grab_marker")
@onready var boss_tilt_platform_origin_marker = get_tree().get_nodes_in_group("boss_tilt_platform_origin_marker")
@onready var boss_intro_path_markers = get_tree().get_nodes_in_group("boss_intro_path_marker")
@onready var hand_spawn_marker = get_tree().get_nodes_in_group("boss_hand_spawn_marker")

@onready var music_player: AudioStreamPlayer = $InteractiveMusicPlayer
var music_playback: AudioStreamPlaybackInteractive


func _ready() -> void:
	remove_child(tilt_particles)
	tiltable_parent.add_child(tilt_particles)
	music_playback = music_player.get_stream_playback()
	
	boss.flying_nav = flying_nav_mesh
	boss.tilt_platform_origin_marker = boss_tilt_platform_origin_marker.front()
	boss.tilt_particles = tilt_particles
	boss.tilt_hand_markers = tilt_grab_markers
	boss.intro_path_points = boss_intro_path_markers
	boss.hand_spawn_pos = hand_spawn_marker.front()
	boss.explosive_spawn_meshes = explosive_spawn_parent.get_children()
	boss.phase_changed.connect(
		func(_a: int):
			music_playback.switch_to_clip(1)
	)
	
	super ()


func _on_killbox_area_body_entered(body: Node3D) -> void:
	if body is PokerChip:
		body.deactivate()
		return
	
	if "health_component" in body:
		if body is Player:
			body.fall_death()
		else:
			body.health_component.damage(9999999)
	else:
		body.queue_free()
