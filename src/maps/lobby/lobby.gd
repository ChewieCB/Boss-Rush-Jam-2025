extends Node3D

# @onready var lobby_music_player: AudioStreamPlayer3D = $LobbyMusicPlayer

signal ui_accept

@onready var player: Player = find_children("*", "Player").front()
@onready var elevator_doors: SlidingDoor = find_children("*", "ElevatorDoors").front()
@onready var elevator_buttons: Array[Node] = find_children("*", "ElevatorButton")

@onready var info_ui: Control = $UI/InfoBoxUI
@onready var game_win_ui: Control = $UI/GameWinUI
@onready var difficulty_menu: DifficultyMenu = $UI/DifficultyMenu

@onready var sfx_door_open: AudioStreamPlayer3D = $SFXDoorOpen
@onready var sfx_door_close: AudioStreamPlayer3D = $SFXDoorClose

@onready var vendors: Array[Node] = find_children("*", "Vendor")

var is_tutorial: bool = false
var display_barrels: Array = []

var no_difficulty_bosses: Array[int] = [BossCore.BossIdEnum.BLACKJACK, BossCore.BossIdEnum.ELEVATOR]


func _ready() -> void:
	Engine.time_scale = 1
	SoundManager.stop_music(0.1)
	for button in elevator_buttons:
		button.pushed.connect(_on_level_select)
	difficulty_menu.bet_started.connect(load_selected_level) # Start load the boss level
	for vendor in vendors:
		vendor.inventory_opened.connect(player.current_gun.play_unequip_anim)
		vendor.inventory_closed.connect(player.current_gun.play_equip_anim)
	
	get_tree().paused = false
	
	GameManager.current_boss_map = self
	
	# Save and load check
	if SaveManager.save_data_is_loaded:
		GameManager.update_total_playtime()
		SaveManager.save_game(GameManager.chosen_slot_id)
	else:
		# First time get to lobby, load data from save file
		GameManager.start_record_playtime()
		SaveManager.load_game(GameManager.chosen_slot_id)
	
	GameManager.reset_reroll_cost()
	GameManager.is_free_reroll = true
	GameManager.bet_value = 0
	GameManager.reward_value = 0
	
	# HACK
	if GameManager.player_gained_first_barrel:
		if not GameManager.barrel_tutorial_shown:
			info_ui.text_no_resize(
				"You've gained a barrel!",
				"Talk to the vendor to change your loadout and buy new barrels."
			)
			show_panel(info_ui)
			GameManager.barrel_tutorial_shown = true
	
	if GameManager.all_bosses_defeated:
		if not GameManager.victory_ui_shown:
			show_panel(game_win_ui)
			GameManager.victory_ui_shown = true
	
	player.stat_ui.show_health_ui()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		ui_accept.emit()


func show_panel(panel: Control) -> void:
	panel.visible = true
	var tween = get_tree().create_tween()
	tween.tween_property(panel, "modulate", Color(Color.WHITE, 1.0), 1.0)
	await tween.finished
	await ui_accept
	tween = get_tree().create_tween()
	tween.tween_property(panel, "modulate", Color(Color.WHITE, 0.0), 1.0)


func _on_level_select(level_path: String) -> void:
	GameManager.selected_level_path = level_path
	if GameManager.selected_boss_id in no_difficulty_bosses:
		load_selected_level()
	else:
		difficulty_menu.show_menu()


func load_selected_level():
<< << << < HEAD
	find_and_load_boss_bgm()
	var level_path = GameManager.selected_level_path
== == == =
	LoadingHandler.start_loading(GameManager.selected_level_path, "", false)
	
>> >> >> > testing
	sfx_door_close.play()
	elevator_doors.close()
	await elevator_doors.anim_player.animation_finished
	
	# Set the skip equip anim flag for seamless transition
	LoadingHandler.skip_equip_anim = true
	# Get the player's position relative to the elevator doors
	GameManager.cached_player_pos_relative_to_elevator_doors = elevator_doors.global_position - GameManager.player.global_position
	GameManager.cached_player_rotation = GameManager.player.rotation
	GameManager.cached_camera_rotation = GameManager.player.player_camera.rotation
<< << << < HEAD
	var loaded_scene = ResourceLoader.load_threaded_get(level_path)
	# HACK - do this properly with dynamic loading of scenes
	if is_inside_tree():
		# TODO - fade this out via tween
		# lobby_music_player.stop()
		# var new_bgm = loaded_scene.get_state().get_node_property_value(0, 1)
		# TODO - fixme
		#if new_bgm:
			#SoundManager.play_music(new_bgm, 0.25, "BGM")
		GameManager.is_free_reroll = false
		get_tree().change_scene_to_packed(loaded_scene)
== == == =
	GameManager.is_free_reroll = false
	lobby_music_player.stop()
	
	LoadingHandler.load_scene_seamless()
>> >> >> > testing


func find_and_load_boss_bgm() -> void:
	match GameManager.selected_boss_id:
		BossCore.BossIdEnum.SLOTS:
			GameManager.change_fmod_bgm_music_state("Slotty")
		BossCore.BossIdEnum.BARTENDER:
			GameManager.change_fmod_bgm_music_state("Bartender")
		BossCore.BossIdEnum.PIT:
			GameManager.change_fmod_bgm_music_state("PitbossHallway")
		BossCore.BossIdEnum.ROULETTE:
			GameManager.change_fmod_bgm_music_state("Roulette")
		BossCore.BossIdEnum.CHIPS:
			GameManager.change_fmod_bgm_music_state("ChipbossInt")
		BossCore.BossIdEnum.BLACKJACK:
			GameManager.change_fmod_bgm_music_state("BlackjackStart")
		BossCore.BossIdEnum.ELEVATOR:
			GameManager.change_fmod_bgm_music_state("TutorialBossfight")


func _on_door_transition_area_body_entered(body: Node3D) -> void:
	if body is Player:
		elevator_doors.open()


func _on_door_transition_area_body_exited(body: Node3D) -> void:
	if body is Player:
		elevator_doors.close()
