extends Control
class_name MainMenu

@export var button_sfx: Array[AudioStream]
@export var start_game_sfx: AudioStream
@export var lobby_scene: PackedScene

@onready var buttons_container: Container = $TitleColumn/VBoxContainer
@onready var buttons = buttons_container.get_children()
@onready var settings_ui: SettingUI = $SettingUI
@onready var credits_ui = $CreditsUI
@onready var story_ui = $StoryUI
@onready var save_ui = $SaveUI
@onready var save_slot_items: Array[Node] = $SaveUI/VBoxContainer.get_children()
@onready var title_column = $TitleColumn

var started_loading = false

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	Input.joy_connection_changed.connect(_on_controller_connection)
	
	for slot: SaveSlotItem in save_slot_items:
		slot.save_deleted.connect(_on_save_deleted)
	
	Engine.time_scale = 1
	SoundManager.stop_music(0.1)
	LoadingHandler.current_scene_path = "res://src/maps/lobby/Lobby.tscn"
	get_tree().paused = false
	
	ScreenTransition.transition_in()
	await ScreenTransition.transition_finished
	
	save_ui.visible = false
	for button in buttons:
		button.pressed.connect(_play_button_sfx)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if save_ui.visible:
			save_ui.visible = false
			buttons_container.get_child(0).grab_focus()
			story_ui.visible = true
		elif settings_ui.visible and not settings_ui.is_remapping:
			settings_ui.visible = false
			buttons_container.get_child(0).grab_focus()
			story_ui.visible = true
		elif credits_ui.visible:
			credits_ui.visible = false
			buttons_container.get_child(0).grab_focus()
			story_ui.visible = true

	if event.is_action_pressed("ui_left"):
		if credits_ui.visible:
			var button_container_has_focus = false
			for child in buttons_container.get_children():
				if child.has_focus():
					button_container_has_focus = true
					break
			if not button_container_has_focus:
				buttons_container.get_child(0).grab_focus()
	
	if event.is_action_pressed("ui_right"):
		if credits_ui.visible:
			for child in buttons_container.get_children():
				child.release_focus()


func _play_button_sfx() -> void:
	SoundManager.play_ui_sound(button_sfx.pick_random(), "UI")


func _on_start_button_pressed() -> void:
	SoundManager.play_button_click_sfx()
	save_ui.visible = true
	story_ui.visible = false
	credits_ui.visible = false
	settings_ui.close_menu()

	# Grab focus the first save button
	var first_save_button: SaveSlotItem = save_slot_items[0]
	first_save_button.main_button.grab_focus()
	

func _on_quit_button_pressed() -> void:
	SoundManager.play_button_click_sfx()
	get_tree().quit()


func _on_option_button_pressed() -> void:
	SoundManager.play_button_click_sfx()
	credits_ui.visible = false
	story_ui.visible = false
	save_ui.visible = false
	settings_ui.open_menu()


func _on_credit_button_pressed() -> void:
	SoundManager.play_button_click_sfx()
	credits_ui.visible = true
	story_ui.visible = false
	save_ui.visible = false
	settings_ui.close_menu()
	for child in buttons_container.get_children():
		child.release_focus()


func start_game():
	# SoundManager.play_ui_sound(start_game_sfx, "UI")
	if not SaveManager.save_data_is_loaded:
		SaveManager.load_game(GameManager.chosen_slot_id)
	if not GameManager.tutorial_completed:
		LoadingHandler.current_scene_path = "res://src/maps/tutorial/TutorialBoss.tscn"
		LoadingHandler.start_loading("Tutorial")
	else:
		LoadingHandler.start_loading("Lobby")


func play_button_hover_sfx():
	SoundManager.play_button_hover_sfx()


func _on_setting_ui_setting_back_button_pressed() -> void:
	buttons_container.visible = true
	settings_ui.close_menu()
	story_ui.visible = true
	title_column.visible = true
	SaveManager.save_setting_config()
	buttons_container.get_child(0).grab_focus()


func _on_grab_focus_timer_timeout() -> void:
	buttons_container.get_child(0).grab_focus()


func _on_controller_connection(_device: int, connected: bool) -> void:
	if connected:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		get_window().grab_focus()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_save_deleted(save_slot: SaveSlotItem) -> void:
	var slot_idx = save_slot_items.find(save_slot)
	save_slot_items[slot_idx].main_button.grab_focus()
