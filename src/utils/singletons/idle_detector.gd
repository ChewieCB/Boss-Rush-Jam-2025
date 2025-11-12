extends Node

@export var enable_play_video = false
@export var idle_time: float = 60.0
@export var video_list: Array[VideoStream] = []

@onready var canvas_layer: CanvasLayer = $TopCanvasLayer
@onready var video_player: VideoStreamPlayer = $TopCanvasLayer/Control/VideoStreamPlayer

# Time in seconds before idle function triggers
var _idle_timer = 0.0
var is_video_playing: bool = false

var saved_bgm_volume = 0
var saved_sfx_volume = 0
var saved_ui_volume = 0
var saved_ambience_volume = 0
var saved_gun_volume = 0

func _ready() -> void:
	canvas_layer.visible = false
	enable_play_video = GameManager.CHEAT_demomode
	idle_time = GameManager.CHEAT_demomode_timeout
	GameManager.demo_time_changed.connect(
		func(time: int):
			_idle_timer = 0.0
			idle_time = time
	)


func _process(delta: float) -> void:
	if not is_video_playing:
		# Increment timer
		_idle_timer += delta

		# If timer exceeds threshold, trigger idle function
		if _idle_timer >= idle_time:
			_on_idle_timeout()
			#_idle_timer =  # optional: reset after triggering

# Detect *any* input without consuming it
func _input(event: InputEvent) -> void:
	if _is_user_input(event):
		stop_idle_video()

# Check if the event counts as user input
func _is_user_input(event: InputEvent) -> bool:
	return (
		event is InputEventKey and not event.echo
		or event is InputEventMouseMotion
		or event is InputEventMouseButton
		or event is InputEventJoypadButton
		or event is InputEventJoypadMotion
	)

func stop_idle_video():
	_idle_timer = 0.0 # reset timer
	video_player.stop()
	canvas_layer.visible = false
	is_video_playing = false

	# Reset audio to saved value
	AudioServer.set_bus_volume_db(1, saved_bgm_volume)
	AudioServer.set_bus_volume_db(2, saved_sfx_volume)
	AudioServer.set_bus_volume_db(3, saved_ui_volume)
	AudioServer.set_bus_volume_db(4, saved_ambience_volume)
	AudioServer.set_bus_volume_db(5, saved_gun_volume)


func play_idle_video() -> void:
	if not enable_play_video:
		return
	
	is_video_playing = true
	# Saved other audio bus volume
	saved_bgm_volume = AudioServer.get_bus_volume_db(1)
	saved_sfx_volume = AudioServer.get_bus_volume_db(2)
	saved_ui_volume = AudioServer.get_bus_volume_db(3)
	saved_ambience_volume = AudioServer.get_bus_volume_db(4)
	saved_gun_volume = AudioServer.get_bus_volume_db(5)

	# Set other audio bus to 0
	AudioServer.set_bus_volume_db(1, linear_to_db(0))
	AudioServer.set_bus_volume_db(2, linear_to_db(0))
	AudioServer.set_bus_volume_db(3, linear_to_db(0))
	AudioServer.set_bus_volume_db(4, linear_to_db(0))
	AudioServer.set_bus_volume_db(5, linear_to_db(0))

	# Place your idle logic here
	# e.g. show screensaver, auto-logout, fade UI, etc.
	video_player.stream = video_list.pick_random()
	video_player.play()
	canvas_layer.visible = true


func _on_idle_timeout() -> void:
	print("No input detected for 1 minute! Running idle function...")
	play_idle_video()
