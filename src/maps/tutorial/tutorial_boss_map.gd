extends BossMap

signal ui_accept

@export var boss_doors: ElevatorDoors
@export var exit_doors: SlidingDoor
@export var arena_1_center: Marker3D
@export var arena_2_center: Marker3D

@export var info_ui_prefab: PackedScene

@onready var smoke_start_trigger: Area3D = $SmokeStartTrigger
@onready var smoke_particles: GPUParticles3D = $SmokeParticles
@onready var smoke_hurt_area: Area3D = $SmokeHurtArea
@onready var sfx_smoke_burst: AudioStreamPlayer3D = $SteamBurstPlayer
@onready var sfx_smoke_loop: AudioStreamPlayer3D = $SteamLoopPlayer
@onready var dash_tutorial_trigger: Area3D = $TutorialInfoTrigger3
@onready var spin_warning_prompt: Area3D = $SpinTooExpensiveWarning
var spin_warning_trigger_active: bool = false

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

var current_trigger_actions: Array[String] = []
var current_close_trigger_max: int = 1
var current_close_trigger_count: int = 0

# MUSIC
@onready var music_player: AudioStreamPlayer = $InteractiveMusicPlayer
var music_playback: AudioStreamPlaybackInteractive

# Intro cutscene
@export var intro_boss_path: Path3D
@export var intro_boss_path_follow: PathFollow3D

# Tutorial prompt triggers
@export_group("Tutorial UI Triggers")
@export var tutorial_1_trigger_shoot: TutorialPopupResource
@export var tutorial_2_trigger_reload: TutorialPopupResource
var reload_tutorial_shown: bool = false


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
	
	if GameManager.cached_player_rotation:
		player.global_position = elevator_doors.global_position - Vector3(0, 0, 1.5)
		player.global_rotation.y = PI
	
	# Disable auto-reloading for reload tutorial, re-enabling it once the prompt is complete
	player.current_gun.is_reload_disabled = true
	player.current_gun.gun_shot.connect(_check_for_reload_tutorial)

	if boss_doors:
		boss_doors.close()
	
	#exit_elevator_button.pushed.connect(_on_level_select)
	#for i in range(chiplings_to_spawn_1):
		#spawn_chipling(1, chipling_spawns_1, chipling_wander_points_1)

	# Trigger tutorial popup when barrel purchased
	#$Vendor1.shop_ui.inventory_closed.connect(_on_barrel_purchased)

	# Trigger spin tutorial popup when barrel effect trigger first hit
	#$BarrelEffectTrigger.triggered.connect(_trigger_spin_tutorial)
	
	music_playback = music_player.get_stream_playback()
	
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

	if Input.is_action_just_pressed("spin_barrels"):
		if GameManager.player_currency < GameManager.reroll_cost:
			if spin_warning_trigger_active:
				spin_warning_prompt._on_body_entered(player)


func show_tutorial_panel(resource: TutorialPopupResource) -> void:
	ui_accept.emit()
	var new_panel: Control = info_ui_prefab.instantiate()
	new_panel.elements = resource.body_items
	current_trigger_actions = resource.close_trigger_actions
	current_close_trigger_max = resource.close_trigger_count
	$UI.add_child(new_panel)
	new_panel.visible = true
	
	var tween = get_tree().create_tween()
	tween.tween_property(new_panel, "modulate", Color(Color.WHITE, 1.0), 0.4)
	
	if resource.timeout > 0.0 and not resource.timeout_on_close:
		await get_tree().create_timer(resource.timeout).timeout
	else:
		await ui_accept
	
	if tween.is_running():
		tween.kill()
	
	if resource.timeout_on_close:
		await get_tree().create_timer(resource.timeout).timeout
	
	tween = get_tree().create_tween()
	tween.tween_property(new_panel, "modulate", Color(Color.WHITE, 0.0), 0.2)


func _on_barrel_purchased() -> void:
	if $TutorialInfoTrigger7:
		if GameManager.equipped_barrels.size() > 0:
			$TutorialInfoTrigger7._on_body_entered(player)

func _trigger_spin_tutorial() -> void:
	if $TutorialInfoTrigger6:
		if $BarrelEffectTrigger.applied_effects.size() == 1:
			$TutorialInfoTrigger6._on_body_entered(player)
			spin_warning_trigger_active = true


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
	player.current_gun.equip_active()
	player.stat_ui.show_all_ui()
	#boss_trigger.queue_free()
	boss.state_chart.send_event("start_phase_1")
	show_tutorial_panel(tutorial_1_trigger_shoot)


func _remove_boss_from_intro_path() -> void:
	var cached_transform: Transform3D = boss.global_transform
	intro_boss_path_follow.remove_child(boss)
	add_child(boss)
	boss.global_transform = cached_transform
	boss.scene_root = self
	intro_boss_path.queue_free()


func _on_level_select(level_path: String, loading_name: String = "") -> void:
	GameManager.tutorial_completed = true
	GameManager.player_currency = 0
	
	if GameManager.chosen_slot_id != -1:
		GameManager.update_total_playtime()
		await SaveManager.save_game(GameManager.chosen_slot_id)

	super(level_path, "Lobby")


func _on_smoke_start_trigger_body_entered(body: Node3D) -> void:
	sfx_smoke_burst.play()
	smoke_particles.emitting = true
	smoke_hurt_area._on_body_entered(body)
	smoke_hurt_area.monitoring = true
	smoke_start_trigger.monitoring = false
	smoke_start_trigger.queue_free()
	# Trigger dash tutorial
	dash_tutorial_trigger._on_body_entered(body)
	await get_tree().create_timer(0.1).timeout
	sfx_smoke_loop.play()


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
