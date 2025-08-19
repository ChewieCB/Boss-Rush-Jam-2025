extends Node3D

@onready var elevator_doors: ElevatorDoors = find_children("*", "ElevatorDoors").front()
@export var elevator_buttons: Array[ElevatorButton]
@onready var difficulty_menu: DifficultyMenu = $UI/DifficultyMenu

func _ready() -> void:
	ScreenTransition.transition_in()
	await ScreenTransition.transition_finished

	for button in elevator_buttons:
		button.pushed.connect(_on_level_select)
	difficulty_menu.bet_started.connect(load_selected_level)
	
	await get_tree().process_frame
	await get_tree().process_frame

	GameManager.reset_reroll_cost()
	GameManager.is_free_reroll = true


func _on_level_select(level_path: String) -> void:
	GameManager.selected_level_path = level_path
	difficulty_menu.show_menu()

func load_selected_level():
	var level_path = GameManager.selected_level_path
	ResourceLoader.load_threaded_request(level_path)
	elevator_doors.close()
	await elevator_doors.anim_player.animation_finished
	# Wait until the level has been loaded on another thread
	while ResourceLoader.load_threaded_get_status(level_path) != ResourceLoader.THREAD_LOAD_LOADED:
		pass
	# Get the player's position relative to the elevator doors
	GameManager.cached_player_pos_relative_to_elevator_doors = elevator_doors.global_position - GameManager.player.global_position
	GameManager.cached_player_rotation = GameManager.player.rotation
	GameManager.cached_camera_rotation = GameManager.player.player_camera.rotation
	var loaded_scene = ResourceLoader.load_threaded_get(level_path)
	# HACK - do this properly with dynamic loading of scenes
  
	if is_inside_tree():
		# TODO - fade this out via tween
		# var new_bgm = loaded_scene.get_state().get_node_property_value(0, 1)
		# TODO - fixme
		#if new_bgm:
			#SoundManager.play_music(new_bgm, 0.25, "BGM")
		GameManager.is_free_reroll = false
		get_tree().change_scene_to_packed(loaded_scene)
