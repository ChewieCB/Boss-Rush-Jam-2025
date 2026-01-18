extends BossMap

signal ui_accept

@export var boss_doors: ElevatorDoors
@export var exit_doors: SlidingDoor
@export var arena_1_center: Marker3D
@export var arena_2_center: Marker3D

@export var info_ui_prefab: PackedScene

#@onready var sfx_smoke_loop: AudioStreamPlayer3D = $SteamLoopPlayer

@export var exit_elevator_button: Area3D
@export var lobby_entry_elevator: Node3D

@export var boss_intro_spawn: Marker3D
@export var boss_laser_spawn_markers: Array[Marker3D]
@onready var elevator_spawns: Array[Node] = get_tree().get_nodes_in_group("boss_elevator_spawn_marker")
@onready var boss_origin: Array[Node] = get_tree().get_nodes_in_group("boss_arena_origin_marker")
@export var sub_elevator_doors: Array[SlidingDoor]
@export var sub_elevator_lights: Array[Node3D]

@export var arena_2_floor_parent: Node3D
@export var arena_2_floor_mesh: MeshInstance3D
@export var arena_1_floor_shock_hazard: Node3D

# SMOKE 
@export var pipe_particle_emitters: Array[GPUParticles3D]
var active_emitters: Array[GPUParticles3D] = []

var current_trigger_actions: Array[String] = []
var current_close_trigger_max: int = 1
var current_close_trigger_count: int = 0

# MUSIC
@onready var music_player: AudioStreamPlayer = $InteractiveMusicPlayer
var music_playback: AudioStreamPlaybackInteractive

# Intro cutscene
@export var intro_boss_path: Path3D
@export var intro_boss_path_follow: PathFollow3D
@export var cutscene_subtitle_label: Label

# Tutorial prompt triggers
@export_group("Tutorial UI Triggers")
@export var tutorial_1_trigger_shoot: TutorialPopupResource
@export var tutorial_2_trigger_reload: TutorialPopupResource
@export var tutorial_3_trigger_jump: TutorialPopupResource
@export var tutorial_4_trigger_dash: TutorialPopupResource
@export var tutorial_5_trigger_barrel_detail: TutorialPopupResource
@export var tutorial_6_trigger_spin: TutorialPopupResource

var reload_tutorial_shown: bool = false
var tutorial_panel_tween: Tween
var active_tutorial_panel: Control


func _ready() -> void:
	#GameManager.equipped_barrels = []
	#player.gun.reinstall_barrels()
	# FIXME - workaround
	is_tutorial = true
	elevator_doors = lobby_entry_elevator
	
	# Generate the navigation for the two walkable areas
	generate_navigation()
	floor_parent = arena_2_floor_parent
	floor_mesh = arena_2_floor_mesh
	super()
	
	boss.tutorial_phase_1_started.connect(_on_tutorial_phase_1_started)
	boss.tutorial_phase_2_started.connect(_on_tutorial_phase_2_started)
	boss.tutorial_phase_3_started.connect(_on_tutorial_phase_3_started)
	boss.trigger_smoke.connect(_on_boss_trigger_smoke)
	boss.end_smoke.connect(stop_all_pipe_emitters)
	boss.shock_floor_hazard = arena_1_floor_shock_hazard
	#
	
	if GameManager.cached_player_rotation:
		player.global_position = elevator_doors.global_position - Vector3(0, 0, 1.5)
		player.global_rotation.y = PI

	if boss_doors:
		boss_doors.close()
	
	music_playback = music_player.get_stream_playback()
	
	player.stat_ui.hide_all_ui()
	await ScreenTransition.transition_finished
	$AnimationPlayer.play("pit_boss_shove")
	await $AnimationPlayer.animation_finished
	_on_boss_trigger_volume_body_entered(player)

	boss.arena_1_center = arena_1_center
	boss.arena_2_center = arena_2_center
	#boss.boss_origin = boss_origin[0]
	#boss.elevator_spawns = elevator_spawns
	#boss.sub_elevator_doors = sub_elevator_doors
	#boss.sub_elevator_lights = sub_elevator_lights
	#boss.intro_spawn_marker = boss_intro_spawn
	#boss.laser_spawn_markers = boss_laser_spawn_markers
	#boss.global_position = boss_intro_spawn.global_position


func _input(event: InputEvent) -> void:
	for action_str in current_trigger_actions:
		if event.is_action(action_str):
			# Prevents stick drift/tiny stick movements from closing the popup
			if event is InputEventJoypadMotion:
				if abs(event.axis_value) < 0.075:
					continue
			
			if action_str == "spin_reload" and reload_tutorial_shown and \
			player.current_gun.is_reload_disabled:
				player.current_gun.is_reload_disabled = false
			
			current_close_trigger_count += 1
			
			# Handle held inputs
			get_tree().create_timer(0.5).timeout.connect(_check_close_trigger_action_held.bind(action_str))
			
			if current_close_trigger_count >= current_close_trigger_max:
				ui_accept.emit()
				current_trigger_actions = []
				current_close_trigger_count = 0


func show_tutorial_panel(resource: TutorialPopupResource) -> void:
	ui_accept.emit()
	var new_panel: Control = info_ui_prefab.instantiate()
	new_panel.elements = resource.body_items
	current_trigger_actions = resource.close_trigger_actions
	current_close_trigger_max = resource.close_trigger_count
	$UI.add_child(new_panel)
	new_panel.visible = true
	
	# If we already have an active tutorial popup, get rid of it before adding a new one
	if active_tutorial_panel:
		if tutorial_panel_tween.is_running():
			tutorial_panel_tween.kill()
			
		tutorial_panel_tween = get_tree().create_tween()
		tutorial_panel_tween.tween_property(active_tutorial_panel, "modulate", Color(Color.WHITE, 0.0), 0.2)
		
		await tutorial_panel_tween.finished
		
		active_tutorial_panel = null
	
	active_tutorial_panel = new_panel
	tutorial_panel_tween = get_tree().create_tween()
	tutorial_panel_tween.tween_property(new_panel, "modulate", Color(Color.WHITE, 1.0), 0.4)
	
	if resource.timeout > 0.0 and not resource.timeout_on_close:
		await get_tree().create_timer(resource.timeout).timeout
	else:
		await ui_accept
	
	if tutorial_panel_tween.is_running():
		tutorial_panel_tween.kill()
	
	if resource.timeout_on_close:
		await get_tree().create_timer(resource.timeout).timeout
	
	tutorial_panel_tween = get_tree().create_tween()
	tutorial_panel_tween.tween_property(new_panel, "modulate", Color(Color.WHITE, 0.0), 0.2)
	await tutorial_panel_tween.finished
	active_tutorial_panel = null


func _on_boss_trigger_volume_body_entered(_body: Node3D) -> void:
	music_playback.switch_to_clip(1)
	exit_doors.close()
	if boss_doors:
		boss_doors.is_autodoor = false
		boss_doors.close()
	boss_trigger.queue_free()
	
	boss.activate()
	
	$AnimationPlayer.play("mechanic_enter")
	await $AnimationPlayer.animation_finished
	
	LuckHandler.enabled = true
	# We need to set these player vars AFTER the cutscene cam exits so they don't get re-set 
	# Disable auto-reloading for reload tutorial, re-enabling it once the prompt is complete
	player.current_gun.is_reload_disabled = true
	player.current_gun.gun_shot.connect(_check_for_reload_tutorial)
	player.dash_disabled = true
	player.max_air_jump = 0
	player.current_gun.equip_active()
	player.stat_ui.show_all_ui()
	
	boss.state_chart.send_event("start_tutorial_arena_1")
	match boss.current_phase:
		1:
			boss.state_chart.send_event("start_tutorial_phase_1")
		2:
			boss.state_chart.send_event("start_tutorial_phase_2")
		3:
			boss.state_chart.send_event("start_tutorial_phase_3")


func _remove_boss_from_intro_path() -> void:
	var cached_transform: Transform3D = boss.global_transform
	intro_boss_path_follow.remove_child(boss)
	add_child(boss)
	boss.global_transform = cached_transform
	boss.global_rotation.x = 0.0
	boss.global_rotation.z = 0.0
	boss.scene_root = self
	intro_boss_path.queue_free()


func _on_level_select(level_path: String, loading_name: String = "") -> void:
	GameManager.tutorial_completed = true
	GameManager.player_currency = 0
	
	if GameManager.chosen_slot_id != -1:
		GameManager.update_total_playtime()
		await SaveManager.save_game(GameManager.chosen_slot_id)

	super(level_path, "Lobby")


func _on_tutorial_phase_1_started() -> void:
	show_tutorial_panel(tutorial_1_trigger_shoot)


func _on_tutorial_phase_2_started() -> void:
	player.max_air_jump = 2
	show_tutorial_panel(tutorial_3_trigger_jump)


func _on_tutorial_phase_3_started() -> void:
	player.dash_disabled = false
	show_tutorial_panel(tutorial_4_trigger_dash)
	trigger_pipe_emitter()



func _on_boss_trigger_smoke(count: int) -> void:
	for i in range(count):
		trigger_pipe_emitter()


func trigger_pipe_emitter(idx: int = -1) -> int:
	var emitter: GPUParticles3D
	if idx >= 0:
		emitter = pipe_particle_emitters.pop_at(idx)
	else:
		emitter = pipe_particle_emitters.pop_at(randi_range(0, pipe_particle_emitters.size() - 1))
	
	if not emitter:
		return -1
	
	active_emitters.push_back(emitter)
	await emitter.spark()
	await emitter.start_smoke()
	
	return idx


func stop_pipe_emitter(idx: int) -> void:
	var emitter: GPUParticles3D = pipe_particle_emitters[idx]
	active_emitters.pop_at(active_emitters.find(emitter))
	pipe_particle_emitters.push_back(emitter)
	
	await emitter.end_smoke()


func stop_all_pipe_emitters() -> void:
	for i in range(active_emitters.size() - 1):
		var _emitter = active_emitters.pop_front()
		_emitter.end_smoke()
		pipe_particle_emitters.push_back(_emitter)


func _on_boss_died(_boss: BossCore = boss) -> void:
	return


func _on_boss_defeated(_boss: BossCore) -> void:
	collect_all_chips()
	print("Chips dropped: %s | Total chip value: %s" % [chips_dropped, chip_value_collected])

	exit_elevator_button.disabled = false
	exit_doors.open()

	if not boss.boss_id in GameManager.bosses_defeated:
		GameManager.bosses_defeated.append(boss.boss_id)
		print(GameManager.bosses_defeated)
		GameManager.all_bosses_defeated = GameManager.bosses_defeated.size() == BossCore.BossIdEnum.size() - 1

	# TODO - re-apply this when we re-visit the tutorial boss
	#reward_bet_money()
	#show_end_panel()


func _check_for_reload_tutorial() -> void:
	if player.current_gun.magazine_ammo_left == 0:
		if not reload_tutorial_shown:
			player.current_gun.can_fire = false
			show_tutorial_panel(tutorial_2_trigger_reload)
			reload_tutorial_shown = true


func _check_close_trigger_action_held(action: String) -> void:
	if Input.is_action_pressed(action):
		if action in current_trigger_actions and current_close_trigger_count < current_close_trigger_max:
			current_close_trigger_count += 1


func _set_subtitle(text: String) -> void:
	cutscene_subtitle_label.text = text
