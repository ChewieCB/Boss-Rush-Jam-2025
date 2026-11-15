extends Control
class_name MainMenu

@export var button_sfx: Array[AudioStream]
@export var start_game_sfx: AudioStream
@export var lobby_scene: PackedScene

@onready var buttons_container: Container = $TitleColumn/VBoxContainer
@onready var buttons = buttons_container.get_children()
@export var settings_ui: SettingUI
@export var credits_ui: Control
@export var story_ui: Control
@export var save_ui: Control
@onready var save_slot_items: Array[Node] = $SaveUI/VBoxContainer.get_children()
@export var title_column: Control
@export var show_story_panel: bool = false

@onready var backdrop_blur: TextureRect = $BlurShader

const BACKDROP_BLUR_AMOUNT: float = 2.0
const BACKDROP_BLUR_TIME: float = 0.25
const ENTER_HUB_FADE_TIME: float = 0.5

var started_loading: bool = false
var input_disabled: bool = true

var backdrop = null
var _blur_tween: Tween


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	story_ui.visible = show_story_panel
	if not LoadingHandler.is_materials_compiled:
		LoadingHandler.initial_load()
		await LoadingHandler.materials_compiled

	# Must place it before connect input signal to avoid mouse finiciky stuff idk
	# it just work
	spawn_backdrop()

	Input.joy_connection_changed.connect(_on_controller_connection)
	for slot: SaveSlotItem in save_slot_items:
		slot.save_deleted.connect(_on_save_deleted)
	for button in buttons:
		button.pressed.connect(_play_button_sfx)

	Engine.time_scale = 1
	SoundManager.stop_music(0.1)
	get_tree().paused = false

	_on_controller_connection(0, GameManager.is_controller_connected)

	ScreenTransition.transition_in()
	await ScreenTransition.transition_finished

	input_disabled = false

	GameManager.main_bgm_emitter.play()


func _input(event: InputEvent) -> void:
	if input_disabled:
		return

	if event.is_action_pressed("ui_page_up"):
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_page_down"):
		get_viewport().set_input_as_handled()

	if event.is_action_pressed("ui_cancel"):
		if save_ui.visible:
			save_ui.visible = false
			buttons_container.get_child(0).grab_focus()
			_show_title_only()
		elif settings_ui.visible and not settings_ui.is_remapping:
			settings_ui.visible = false
			buttons_container.get_child(1).grab_focus()
			_show_title_only()
		elif credits_ui.visible:
			credits_ui.visible = false
			buttons_container.get_child(2).grab_focus()
			_show_title_only()


func spawn_backdrop() -> void:
	backdrop = lobby_scene.instantiate()
	backdrop.is_menu_backdrop = true
	add_child(backdrop)
	move_child(backdrop, 0)


func _show_title_only() -> void:
	story_ui.visible = show_story_panel
	_set_backdrop_blur(false)


# Blur the hub while a panel is open so the panel is easier to read
func _set_backdrop_blur(enabled: bool) -> void:
	if _blur_tween:
		_blur_tween.kill()
	if enabled:
		backdrop_blur.visible = true
	_blur_tween = create_tween()
	_blur_tween.tween_property(
		backdrop_blur.material, "shader_parameter/blur_amount",
		BACKDROP_BLUR_AMOUNT if enabled else 0.0, BACKDROP_BLUR_TIME
	)
	if not enabled:
		_blur_tween.tween_callback(backdrop_blur.hide)


func _play_button_sfx() -> void:
	SoundManager.play_ui_sound(button_sfx.pick_random(), "UI")


func _on_start_button_pressed() -> void:
	SoundManager.play_button_click_sfx()
	story_ui.visible = false
	credits_ui.visible = false
	settings_ui.close_menu()
	save_ui.visible = true
	_set_backdrop_blur(true)

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
	_set_backdrop_blur(true)


func _on_credit_button_pressed() -> void:
	SoundManager.play_button_click_sfx()
	story_ui.visible = false
	save_ui.visible = false
	settings_ui.close_menu()
	credits_ui.visible = true
	_set_backdrop_blur(true)
	for child in buttons_container.get_children():
		child.release_focus()


func start_game():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	input_disabled = true
	started_loading = true
	# SoundManager.play_ui_sound(start_game_sfx, "UI")
	SaveManager.load_game(GameManager.chosen_slot_id)

	# Zero any stored positions when moving between saves
	GameManager.cached_player_pos_relative_to_elevator_doors = Vector3.ZERO
	GameManager.cached_player_rotation = Vector3.ZERO
	GameManager.cached_camera_rotation = Vector3.ZERO

	if GameManager.tutorial_completed:
		_enter_hub_seamless()
		return

	# New game: the tutorial is a different map, so it needs a loading screen
	LoadingHandler.start_loading(
		LoadingHandler.level_paths[LoadingHandler.LEVELS.TUTORIAL],
		"Tutorial"
	)

	await ScreenTransition.transition_finished
	LoadingHandler.load_scene_transition()
	save_ui.visible = false


# Existing save: we are already looking at the hub, so no loading screen.
# Fade the menu away, then swap the backdrop for a playable hub that starts
# from the same camera view. The backdrop itself is not reused because it was
# built before the save was loaded (gun, shop, HUD all read the save on ready).
func _enter_hub_seamless() -> void:
	_set_backdrop_blur(false)
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, ENTER_HUB_FADE_TIME)
	backdrop.settle_menu_camera(ENTER_HUB_FADE_TIME)
	await fade_tween.finished

	# Reuse the respawn transform so the player starts exactly where the
	# backdrop's player is standing
	GameManager.elevator_respawn_transform = backdrop.player.global_transform
	LoadingHandler.skip_transition_in = true

	# Swap by hand instead of change_scene_to_packed(): that one detaches the
	# old scene now but only frees it later, and in that gap autoload signals
	# (e.g. the luck decay timer) still reach the detached backdrop player,
	# whose UI then calls get_tree() on null. Here the menu stays in the tree
	# until it is freed at the end of this frame, so there is no gap.
	var tree := get_tree()
	var hub = lobby_scene.instantiate()
	tree.root.add_child(hub)
	tree.current_scene = hub
	queue_free()


func play_button_hover_sfx():
	SoundManager.play_button_hover_sfx()


func _on_setting_ui_setting_back_button_pressed() -> void:
	buttons_container.visible = true
	settings_ui.close_menu()
	_show_title_only()
	title_column.visible = true
	SaveManager.save_setting_config()
	buttons_container.get_child(0).grab_focus()


func _on_controller_connection(_device: int, connected: bool) -> void:
	if connected:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		get_window().grab_focus()
		buttons_container.get_child(0).grab_focus()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _on_save_deleted(save_slot: SaveSlotItem) -> void:
	var slot_idx = save_slot_items.find(save_slot)
	save_slot_items[slot_idx].main_button.grab_focus()
