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
@export var player_spawn_post_tutorial: Marker3D

@export var arena_2_floor_parent: Node3D
@export var arena_2_floor_mesh: MeshInstance3D
@export var arena_1_floor_shock_hazard: Node3D

# SMOKE
@export var pipe_particle_emitters: Array[GPUParticles3D]
var inactive_pipe_emitters: Array[GPUParticles3D] = pipe_particle_emitters
var active_pipe_emitters: Array[GPUParticles3D] = []
#
@export var sfx_pipe_creak_sfx: Array[AudioStream]
@export var sfx_pipe_steam_sfx: Array[AudioStream]

var current_trigger_actions: Array[String] = []
var current_close_trigger_max: int = 1
var current_close_trigger_count: int = 0

# Intro cutscene
@export var cutscene_ui_layer: CanvasLayer
@export var intro_boss_path: Path3D
@export var intro_boss_path_follow: PathFollow3D
@export var tutorial_end_boss_marker: Marker3D
@export var cutscene_subtitle_label: Label
@export var cutscene_camera: Camera3D
var is_cutscene_active: bool = true

# Tutorial prompt triggers
@export_group("Tutorial UI Triggers")
@export var tutorial_1_trigger_shoot: TutorialPopupResource
@export var tutorial_2_trigger_reload: TutorialPopupResource
@export var tutorial_3_trigger_jump: TutorialPopupResource
@export var tutorial_4_trigger_dash: TutorialPopupResource
@export var tutorial_5_trigger_barrel_detail: TutorialPopupResource
@export var tutorial_6_trigger_spin: TutorialPopupResource

#
@export var electric_box_trigger: StaticBody3D
@export var spark_sfx_player: AudioStreamPlayer3D
@export var sfx_door_spark: Array[AudioStream]
@export var door_spark_emitter: GPUParticles3D
@export var door_trigger_highlight_mesh: MeshInstance3D

var reload_tutorial_shown: bool = false
var tutorial_panel_tween: Tween
var active_tutorial_panel: Control


func _ready() -> void:
	if not GameManager.tutorial_completed:
		player.toggle_anim_reticle(false)
		GameManager.equipped_barrels = [null, null, null]
		GameManager.inventory_barrels = []
		player.gun.reinstall_barrels()
		GameManager.change_fmod_bgm_music_state("TutorialStart")
	else:
		GameManager.change_fmod_bgm_music_state("TutorialInterlude")

	GameManager.current_boss_map = self


	# FIXME - workaround
	elevator_doors = lobby_entry_elevator

	# Generate the navigation for the two walkable areas
	generate_navigation()
	floor_parent = arena_2_floor_parent
	floor_mesh = arena_2_floor_mesh

	super()

	boss.tutorial_phase_1_started.connect(_on_tutorial_phase_1_started)
	boss.tutorial_phase_2_started.connect(_on_tutorial_phase_2_started)
	boss.tutorial_phase_3_started.connect(_on_tutorial_phase_3_started)
	boss.tutorial_phases_finished.connect(_on_tutorial_finished)
	boss.tutorial_barrel_collected.connect(_on_tutorial_barrel_collected)
	boss.trigger_smoke.connect(_on_boss_trigger_smoke)
	boss.end_smoke.connect(stop_all_pipe_emitters)
	boss.shock_floor_hazard_tutorial = arena_1_floor_shock_hazard
	boss.arena_1_center = arena_1_center
	boss.arena_2_center = arena_2_center
	boss.sub_elevator_doors = sub_elevator_doors
	boss.sub_elevator_lights = sub_elevator_lights
	boss.elevator_spawns = elevator_spawns
	boss.intro_spawn_marker = boss_intro_spawn
	boss.laser_spawn_markers = boss_laser_spawn_markers

	if boss_doors:
		boss_doors.close()

	player.stat_ui.hide_all_ui()

	if GameManager.tutorial_completed:
		boss.current_phase = 4
		player.global_transform = player_spawn_post_tutorial.global_transform

	if boss.current_phase < 4:
		await ScreenTransition.transition_finished
		$AnimationPlayer.play("pit_boss_shove")
		await $AnimationPlayer.animation_finished
		_on_boss_trigger_volume_body_entered_tutorial(player)
	else:
		_add_boss_to_intro_path()
		_remove_boss_from_intro_path()
		boss.global_position = arena_2_center.global_position
		await boss.inactive_loaded
		boss.state_chart.send_event("start_main_fight")
		electric_box_trigger.active = true
		electric_box_trigger.activate()
		player._disable_cutscene_cam()
		cutscene_ui_layer.visible = false
		cutscene_ui_layer.process_mode = Node.PROCESS_MODE_DISABLED
		cutscene_camera.process_mode = Node.PROCESS_MODE_DISABLED
		#await ScreenTransition.transition_finished
		player.stat_ui.show_all_ui()


func _input(event: InputEvent) -> void:
	# FIXME - buggy, disabling for now
	#if event is InputEventKey:
		#if is_cutscene_active:
			#if not event.is_action("ui_cancel"):
				#skip_cutscene()
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
			get_tree().create_timer(0.5, false).timeout.connect(_check_close_trigger_action_held.bind(action_str))

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
		await get_tree().create_timer(resource.timeout, false).timeout
	else:
		await ui_accept

	if tutorial_panel_tween.is_running():
		tutorial_panel_tween.kill()

	if resource.timeout_on_close:
		await get_tree().create_timer(resource.timeout, false).timeout

	tutorial_panel_tween = get_tree().create_tween()
	tutorial_panel_tween.tween_property(new_panel, "modulate", Color(Color.WHITE, 0.0), 0.2)
	await tutorial_panel_tween.finished
	active_tutorial_panel = null


func _on_boss_trigger_volume_body_entered_tutorial(_body: Node3D) -> void:
	exit_doors.close()
	if boss_doors:
		boss_doors.is_autodoor = false
		boss_doors.close()

	boss.activate()
	if is_cutscene_active:
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


func _on_boss_trigger_volume_body_entered(_body: Node3D) -> void:
	GameManager.change_fmod_bgm_music_state("TutorialInterlude")
	GameManager.change_fmod_bgm_music_state("TutorialBossfight")

	exit_doors.close()
	if boss_doors:
		boss_doors.is_autodoor = false
		boss_doors.close()
	boss_trigger.queue_free()

	# TODO - re-enable when we have a main fight intro
	#boss.activate()

	boss.health_ui.clear_sub_health_bars()
	match boss.current_phase:
		4:
			boss.health_ui.init_boss_health_ui(boss.main_health, 2)
			boss.state_chart.send_event("start_tutorial_phase_4")
		5:
			boss.health_ui.init_boss_health_ui(boss.phase_5_health, 1)
			boss.state_chart.send_event("start_tutorial_phase_5")

	boss.health_ui.show_ui()


func skip_cutscene() -> void:
	is_cutscene_active = false
	$AnimationPlayer.advance(10000)
	$AnimationPlayer.stop()
	$AnimationPlayer.play("cutscene_skip")
	await $AnimationPlayer.animation_finished


func _add_boss_to_intro_path() -> void:
	if not is_instance_valid(intro_boss_path_follow):
		return
	boss.reparent(intro_boss_path_follow)
	boss.position = Vector3.ZERO


func _remove_boss_from_intro_path() -> void:
	if not is_instance_valid(intro_boss_path_follow):
		return
	if boss.get_parent() != intro_boss_path_follow:
		return
	var cached_transform: Transform3D = boss.global_transform
	intro_boss_path_follow.remove_child(boss)
	add_child(boss)
	boss.global_transform = cached_transform
	boss.global_rotation.x = 0.0
	boss.global_rotation.z = 0.0
	boss.scene_root = self
	intro_boss_path.queue_free()
	# Should stop the animations breaking since we've changed the node order, we forcibly update the animation path
	$AnimationPlayer.get_animation("tutorial_end_3").track_set_path(0, "entity_187_TutorialBoss")


func _on_level_select(level_path: String, _loading_name: String = "") -> void:
	GameManager.tutorial_completed = true
	GameManager.player_currency = 0
	
	boss.cleanup_pools.call_deferred()
	
	if GameManager.chosen_slot_id != -1:
		GameManager.update_total_playtime()
		await SaveManager.save_game(GameManager.chosen_slot_id)
	
	super(level_path, "Lobby")


func _on_tutorial_phase_1_started() -> void:
	show_tutorial_panel(tutorial_1_trigger_shoot)


func _on_tutorial_phase_2_started() -> void:
	reload_tutorial_shown = true
	player.current_gun.is_reload_disabled = false
	player.max_air_jump = 1
	show_tutorial_panel(tutorial_3_trigger_jump)


func _on_tutorial_phase_3_started() -> void:
	player.dash_disabled = false
	show_tutorial_panel(tutorial_4_trigger_dash)
	trigger_pipe_emitter()


func _on_tutorial_finished() -> void:
	stop_all_pipe_emitters()

	GameManager.change_fmod_bgm_music_state("TutorialInterlude")
	# Move cutscene camera to match player's camera
	cutscene_ui_layer.visible = true
	cutscene_ui_layer.process_mode = Node.PROCESS_MODE_INHERIT
	cutscene_camera.process_mode = Node.PROCESS_MODE_INHERIT
	cutscene_camera.global_transform = player.player_camera.global_transform
	player._enable_cutscene_cam()

	# Move boss to doorway - dynamic cutscene tween
	var move_pos: Vector3 = tutorial_end_boss_marker.global_position
	var move_time: float = boss.global_position.distance_to(move_pos) / boss.MAX_SPEED
	var camera_goal_pos := Vector3(-36.2, 2.6, 20.4)
	var camera_goal_rot := Vector3(-2.1, 0, 0)
	#var final_transform = cutscene_camera.global_transform.looking_at(camera_goal_pos, Vector3.UP)
	var boss_move_tween: Tween = get_tree().create_tween()
	boss_move_tween.set_parallel(true).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CIRC)
	boss_move_tween.tween_property(
		boss, "global_position", move_pos, move_time
	)
	boss_move_tween.tween_property(
		cutscene_camera, "global_rotation_degrees", camera_goal_rot, move_time
	)
	boss_move_tween.tween_property(
		cutscene_camera, "global_position", camera_goal_pos, move_time
	)

	await boss_move_tween.finished

	# Play fixed cutscene
	$AnimationPlayer.play("tutorial_end_1")
	await $AnimationPlayer.animation_finished

	# Play dialogue line
	var dialogue_idx: int = randi_range(0, boss.sfx_tutorial_end_taunts.size() - 2)
	var taunt_sfx = boss.sfx_tutorial_end_taunts[dialogue_idx]
	await play_vo_with_captions(taunt_sfx, boss.tutorial_end_taunt_captions[dialogue_idx])
	await get_tree().create_timer(0.4, false).timeout
	await play_vo_with_captions(boss.sfx_tutorial_end_taunts[-1], boss.tutorial_end_taunt_captions[-1])
	# TODO - move camera using taunt_sfx.get_length

	# Throw barrel to player
	$AnimationPlayer.play("tutorial_end_2")
	await $AnimationPlayer.animation_finished

	await play_vo_with_captions(boss.sfx_tutorial_barrel[0], boss.tutorial_barrel_captions[0])
	await get_tree().create_timer(0.3, false).timeout
	await play_vo_with_captions(boss.sfx_tutorial_barrel[1], boss.tutorial_barrel_captions[1])

	# Move through doors, locking doors behind
	$AnimationPlayer.play("tutorial_end_3")
	await $AnimationPlayer.animation_finished

	# Tween the camera back
	player.player_camera.rotation.y = 0
	player.player_camera.rotation.z = 0
	var camera_tween = get_tree().create_tween().set_parallel(true).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	camera_tween.tween_property(
		cutscene_camera, "global_transform", player.player_camera.global_transform, 0.4
	)
	#camera_tween.tween_property(
		#cutscene_camera, "rotation", player.player_camera.rotation, 0.4
	#)
	$AnimationPlayer.play("cutscene_letterbox_end")

	await camera_tween.finished

	player._disable_cutscene_cam()
	cutscene_ui_layer.visible = false
	cutscene_ui_layer.process_mode = Node.PROCESS_MODE_DISABLED
	cutscene_camera.process_mode = Node.PROCESS_MODE_DISABLED
	electric_box_trigger.active = true
	boss.state_chart.send_event("start_main_fight")
	boss.current_phase = 4


func _on_tutorial_barrel_collected(barrel_data: BarrelDataResource) -> void:
	# Auto-equip the barrel onto the gun
	player.gun.cancel_reload()
	GameManager.equip_barrel(barrel_data.barrel_id)

	# Force effect to non-electric and 1st spin to electric
	await player.current_gun.recheck_installed_barrels()
	player.current_gun.set_barrel_to_effect(0, 27) # 27 = Gambler's Precision
	player.current_gun.force_barrel_next_spin(0, 51) # 51 = Hyperfocus

	await get_tree().create_timer(0.8, false).timeout

	await show_tutorial_panel(tutorial_5_trigger_barrel_detail)

	# Spark the electrical box
	door_spark_emitter.emitting = true
	spark_sfx_player.stream = sfx_door_spark.pick_random()
	spark_sfx_player.play()
	# Highlight electrical box to shoot
	# TODO - modulate coloured mesh around box
	#
	# Trigger spin tutorial prompt
	GameManager.is_free_reroll = true
	show_tutorial_panel(tutorial_6_trigger_spin)

	while electric_box_trigger.active:
		await get_tree().create_timer(randf_range(1.0, 1.8)).timeout
		# Spark the electrical box
		door_spark_emitter.emitting = true
		spark_sfx_player.stream = sfx_door_spark.pick_random()
		spark_sfx_player.play()
		#
		var highlight_tween: Tween = get_tree().create_tween()
		highlight_tween.tween_method(
			_update_shield_mat_colour.bind(door_trigger_highlight_mesh),
			Color("d9002b00"),
			Color("d9002b"),
			0.6
		).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CIRC)
		highlight_tween.chain().tween_method(
			_update_shield_mat_colour.bind(door_trigger_highlight_mesh),
			Color("d9002b"),
			Color("d9002b00"),
			0.4
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CIRC)

	GameManager.is_free_reroll = false


func _update_shield_mat_colour(color: Color, mesh: MeshInstance3D) -> void:
	var mat: ShaderMaterial = mesh.get_active_material(0)
	mat.set_shader_parameter("color", color)


func _on_boss_trigger_smoke(count: int) -> void:
	for i in range(count):
		trigger_pipe_emitter()


func trigger_pipe_emitter(idx: int = -1) -> void:
	if idx < 0:
		idx = randi_range(0, pipe_particle_emitters.size() - 1)

	var emitter: GPUParticles3D = pipe_particle_emitters[idx]
	if emitter in active_pipe_emitters:
		return

	var inactive_idx: int = inactive_pipe_emitters.find(emitter)
	inactive_pipe_emitters.pop_at(inactive_idx)
	active_pipe_emitters.push_back(emitter)
	#
	var emitter_sfx_player: AudioStreamPlayer3D = emitter.get_node("AudioStreamPlayer3D")
	emitter_sfx_player.stream = sfx_pipe_creak_sfx.pick_random()
	emitter_sfx_player.play()
	await emitter.spark()
	await emitter_sfx_player.finished
	#
	emitter_sfx_player.stream = sfx_pipe_steam_sfx.pick_random()
	emitter_sfx_player.play()
	await emitter.start_smoke()


func stop_pipe_emitter(idx: int) -> void:
	if idx < 0:
		idx = randi_range(0, pipe_particle_emitters.size() - 1)

	var emitter: GPUParticles3D = pipe_particle_emitters[idx]
	if emitter in inactive_pipe_emitters:
		return

	var active_idx: int = active_pipe_emitters.find(emitter)
	active_pipe_emitters.pop_at(active_idx)
	inactive_pipe_emitters.push_back(emitter)

	var emitter_sfx_player: AudioStreamPlayer3D = emitter.get_node("AudioStreamPlayer3D")
	emitter_sfx_player.stop()

	await emitter.end_smoke()


func stop_all_pipe_emitters() -> void:
	for i in range(pipe_particle_emitters.size() - 1):
		stop_pipe_emitter(i)


func _align_player_camera_to_cutscene_camera() -> void:
	player.player_camera.global_rotation = cutscene_camera.global_rotation


func _on_player_death() -> void:
	if GameManager.tutorial_completed:
		# TODO - play kicked back to lobby cutscene with boss VO
		#
		boss.cleanup_shock_hazards()
		win_ui.lose()
		show_end_panel()
	else:
		# Put the boss in a passive state while we play the tutorial
		boss.state_chart.send_event("player_defeated_reset")

		if boss.current_phase > 3:
			GameManager.tutorial_completed = true
			_on_player_death()
			return

		await get_tree().create_timer(0.6, false).timeout

		# Move cutscene camera to match player's camera
		cutscene_ui_layer.visible = true
		cutscene_ui_layer.process_mode = Node.PROCESS_MODE_INHERIT
		cutscene_camera.process_mode = Node.PROCESS_MODE_INHERIT
		cutscene_camera.global_transform = player.player_camera.global_transform
		player._enable_cutscene_cam()

		# Lerp cutscene camera to boss
		var camera_tween: Tween = get_tree().create_tween().set_parallel(true).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		var final_transform = cutscene_camera.global_transform.looking_at(boss.global_position, Vector3.UP)
		var boss_pos_start: Vector3 = boss.global_position - boss.global_basis.z * 5.0 + Vector3(0, 2.8, 0)
		var boss_pos_end: Vector3 = boss.global_position - boss.global_basis.z * 3.0 + Vector3(0, 3.2, 0)
		camera_tween.tween_property(
			cutscene_camera, "global_transform", final_transform, 0.7
		)
		camera_tween.tween_property(
			cutscene_camera, "global_position", boss_pos_start, 0.7
		)

		# Play letterbox animation for subtitles
		$AnimationPlayer.play("cutscene_letterbox_start")
		await camera_tween.finished

		# Play sound
		# TODO - replace with paired resource class of audio & captions
		var defeat_sfx: AudioStream = boss.sfx_player_defeated_taunt.pick_random()
		var sfx_idx: int = boss.sfx_player_defeated_taunt.find(defeat_sfx)
		var defeat_text: String = boss.player_defeated_taunt_captions[sfx_idx]
		SoundManager.play_sound(defeat_sfx)
		camera_tween = get_tree().create_tween().set_parallel(true)
		#camera_tween.tween_property(cutscene_camera, "fov", 90, defeat_sfx.get_length())
		camera_tween.tween_property(cutscene_camera, "global_position", boss_pos_end, defeat_sfx.get_length())
		camera_tween.tween_property(cutscene_camera, "global_rotation:x", cutscene_camera.global_rotation.x + deg_to_rad(10), defeat_sfx.get_length())
		# Tween the subtitle text
		cutscene_subtitle_label.visible_ratio = 0.0
		# TODO - assign subtitles to each audio sample and show them here
		cutscene_subtitle_label.text = defeat_text
		camera_tween.tween_property(cutscene_subtitle_label, "visible_ratio", 1.0, defeat_sfx.get_length())
		await camera_tween.finished

		await get_tree().create_timer(0.4, false).timeout
		cutscene_subtitle_label.text = ""

		# Tween the camera back
		camera_tween = get_tree().create_tween().set_parallel(true).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		camera_tween.tween_property(
			cutscene_camera, "global_transform", player.player_camera.global_transform, 0.4
		)
		camera_tween.tween_property(cutscene_camera, "fov", 75, 0.4)
		$AnimationPlayer.play("cutscene_letterbox_end")
		await camera_tween.finished
		player._disable_cutscene_cam()
		cutscene_ui_layer.visible = false
		cutscene_ui_layer.process_mode = Node.PROCESS_MODE_DISABLED
		cutscene_camera.process_mode = Node.PROCESS_MODE_DISABLED

		await get_tree().create_timer(0.4, false).timeout

		# Give the player their health back
		player.health_component.heal(player.health_component.max_health)
		player.state_chart.send_event("revive")

		# Restart the current phase
		match boss.current_phase:
			1:
				boss.state_chart.send_event("start_tutorial_phase_1")
			2:
				boss.state_chart.send_event("start_tutorial_phase_2")
			3:
				boss.state_chart.send_event("start_tutorial_phase_3")


func play_vo_with_captions(sfx_stream: AudioStream, caption_text: String) -> void:
	SoundManager.play_sound(sfx_stream)
	var cutscene_length: float = sfx_stream.get_length()
	var tween = get_tree().create_tween().set_parallel(true)
	# Tween the subtitle text
	cutscene_subtitle_label.visible_ratio = 0.0
	# TODO - assign subtitles to each audio sample and show them here
	cutscene_subtitle_label.text = caption_text
	tween.tween_property(cutscene_subtitle_label, "visible_ratio", 1.0, cutscene_length)
	await tween.finished

	await get_tree().create_timer(0.4, false).timeout

	cutscene_subtitle_label.text = ""
	return


func show_end_panel() -> void:
	boss.cleanup_pools.call_deferred()
	
	LuckHandler.enabled = false
	win_ui.visible = true
	var tween = get_tree().create_tween()
	tween.tween_property(win_ui, "modulate", Color(Color.WHITE, 1.0), 1.0)
	await tween.finished
	await get_tree().create_timer(2.5, false).timeout
	tween = get_tree().create_tween()
	tween.tween_property(win_ui, "modulate", Color(Color.WHITE, 0.0), 1.0)
	await tween.finished

	# TODO - have the player respawn at the boss fight, maybe load TUTORIAL_BOSS_ONLY instead?
	LoadingHandler.start_loading(
		LoadingHandler.level_paths[LoadingHandler.LEVELS.BACKROOM],
		"Back Room"
	)
	await ScreenTransition.transition_finished
	LoadingHandler.load_scene_transition()


func _on_boss_died(_boss: BossCore = boss) -> void:
	return


func _on_boss_defeated(_boss: BossCore) -> void:
	GameManager.tutorial_completed = true

	collect_all_chips()
	print("Chips dropped: %s | Total chip value: %s" % [chips_dropped, chip_value_collected])

	boss.cleanup_shock_hazards()

	#exit_elevator_button.disabled = false
	#exit_doors.open()

	if not boss.boss_id in GameManager.bosses_defeated:
		GameManager.bosses_defeated.append(boss.boss_id)
		print(GameManager.bosses_defeated)
		GameManager.all_bosses_defeated = GameManager.bosses_defeated.size() == BossCore.BossIdEnum.size() - 1

	# TODO - re-apply this when we re-visit the tutorial boss
	#reward_bet_money()
	show_end_panel()


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
