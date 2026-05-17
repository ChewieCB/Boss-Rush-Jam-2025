extends Node3D

# @onready var lobby_music_player: AudioStreamPlayer3D = $LobbyMusicPlayer

signal ui_accept

@export var player: Player
#@onready var elevator_doors: SlidingDoor = find_children("*", "ElevatorDoors").front()
@export var elevator_buttons: Array[ElevatorButton]

@onready var ui_layer: CanvasLayer = $UI
@onready var info_ui: Control = $UI/InfoBoxUI
@onready var game_win_ui: Control = $UI/GameWinUI
@onready var difficulty_menu: DifficultyMenu = $UI/DifficultyMenu

@onready var sfx_door_open: AudioStreamPlayer3D = $SFXDoorOpen
@onready var sfx_door_close: AudioStreamPlayer3D = $SFXDoorClose

@export var vendors: Array[Node]

var display_barrels: Array = []

var no_difficulty_bosses: Array[int] = [BossCore.BossIdEnum.BLACKJACK, BossCore.BossIdEnum.ELEVATOR]


func _ready() -> void:
	Engine.time_scale = 1
	#SoundManager.stop_music(0.1)
	for button in elevator_buttons:
		if button:
			button.pushed.connect(_on_level_select)
	difficulty_menu.bet_started.connect(load_selected_level) # Start load the boss level
	for vendor in vendors:
		vendor.inventory_opened.connect(player.current_gun.play_unequip_anim)
		vendor.inventory_closed.connect(player.current_gun.play_equip_anim)
	
	ui_layer.visible = false
	ui_layer.process_mode = Node.PROCESS_MODE_DISABLED
	
	get_tree().paused = false
	
	GameManager.current_boss_map = self
	GameManager.change_fmod_bgm_music_state("Backroom") # Backroom is the new Lobby
	
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
	
	if GameManager.elevator_respawn_transform:
		player.global_transform = GameManager.elevator_respawn_transform
	
	# HACK for backroom load
	await ScreenTransition.transition_in()
	
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
	
	player.stat_ui.show_all_ui()
	player.controls_disabled = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		ui_accept.emit()


func show_panel(panel: Control) -> void:
	ui_layer.visible = true
	ui_layer.process_mode = Node.PROCESS_MODE_INHERIT
	panel.visible = true
	
	var tween = get_tree().create_tween()
	tween.tween_property(panel, "modulate", Color(Color.WHITE, 1.0), 1.0)
	await tween.finished
	await ui_accept
	tween = get_tree().create_tween()
	tween.tween_property(panel, "modulate", Color(Color.WHITE, 0.0), 1.0)
	await tween.finished
	
	ui_layer.visible = false
	ui_layer.process_mode = Node.PROCESS_MODE_DISABLED


func _on_level_select(level_path: String, _elevator_doors: ElevatorDoors, _respawn_marker: Marker3D) -> void:
	GameManager.selected_level_path = level_path
	GameManager.elevator_respawn_transform = _respawn_marker.global_transform
	if GameManager.selected_boss_id in no_difficulty_bosses:
		load_selected_level(_elevator_doors)
	else:
		difficulty_menu.show_menu()


func load_selected_level(_elevator_doors: ElevatorDoors = null):
	find_and_load_boss_bgm()
	await LoadingHandler.start_loading(GameManager.selected_level_path, "", true)
	sfx_door_close.play()
	
	if _elevator_doors:
		_elevator_doors.close()
		#await elevator_doors.anim_player.animation_finished
		
		# Set the skip equip anim flag for seamless transition
		LoadingHandler.skip_equip_anim = false
		## Get the player's position relative to the elevator doors
		#GameManager.cached_player_pos_relative_to_elevator_doors = _elevator_doors.global_position - GameManager.player.global_position
		#GameManager.cached_player_rotation = GameManager.player.rotation
		#GameManager.cached_camera_rotation = GameManager.player.player_camera.rotation
		#GameManager.elevator_respawn_rotation = -_elevator_doors.basis.z
	#else:
		#GameManager.cached_player_pos_relative_to_elevator_doors = Vector3.ZERO
		#GameManager.cached_player_rotation = Vector3.ZERO
		#GameManager.cached_camera_rotation = Vector3.ZERO
		#GameManager.elevator_respawn_rotation = Vector3.ZERO
	
	GameManager.is_free_reroll = false
	
	#LoadingHandler.load_scene_seamless()
	LoadingHandler.load_scene_transition()


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
			GameManager.change_fmod_bgm_music_state("ChipbossStart")
		BossCore.BossIdEnum.BLACKJACK:
			GameManager.change_fmod_bgm_music_state("BlackjackStart")
		BossCore.BossIdEnum.ELEVATOR:
			GameManager.change_fmod_bgm_music_state("TutorialBossfight")


#func _on_door_transition_area_body_entered(body: Node3D) -> void:
	#if body is Player:
		#elevator_doors.open()
#
#
#func _on_door_transition_area_body_exited(body: Node3D) -> void:
	#if body is Player:
		#elevator_doors.close()
