extends Node3D

@export var bpm: float = 120.0
@export var pulse_scale: float = 1.05 # max scale factor
@export var pulse_duration: float = 0.2 # how fast pulse animates (seconds)

@export var sprite_list: Array[Texture2D] = []

@export var lyrics: Array[String] = [
	"Night falls and I'm taken by sleep",
	"Hot air blows up balloons in my dreams",
	"Ding dong, rings the bell",
	"Something is at the door",
	"So I put on my slippers",
	"And I creep across the floor"
]
@export var word_delay := 0.3 # seconds between each word
@export var line_pause := 0.8 # pause before next line

@onready var sprite: Sprite3D = $Sprite3D
@onready var lyric_label: Label3D = $Label3D

var _original_scale_y: float
var _beat_timer: Timer
var _tween: Tween
var current_sprite_index = 0

func _ready():
	_original_scale_y = sprite.scale.y

	_beat_timer = Timer.new()
	_beat_timer.wait_time = 60.0 / bpm
	_beat_timer.autostart = true
	_beat_timer.one_shot = false
	_beat_timer.timeout.connect(_on_beat)
	add_child(_beat_timer)

	play_lyrics()


func _process(delta: float) -> void:
	_turn_towards_target(5, delta)


func _on_beat():
	# Change sprite
	current_sprite_index += 1
	if current_sprite_index > len(sprite_list) - 1:
		current_sprite_index = 0
		sprite.scale.x = - sprite.scale.x
	sprite.texture = sprite_list[current_sprite_index]


	# Cancel previous tween if still playing
	if _tween and _tween.is_running():
		_tween.stop()
		sprite.scale.y = _original_scale_y

	_tween = create_tween()
	# Pulse out
	_tween.tween_property(sprite, "scale:y", _original_scale_y * pulse_scale, pulse_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Pulse back in
	_tween.tween_property(sprite, "scale:y", _original_scale_y, pulse_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func play_lyrics() -> void:
	await display_lyrics()
	print("All lyrics finished")

func display_lyrics() -> void:
	for line in lyrics:
		await display_line(line)
		lyric_label.text = "" # clear line
		await get_tree().create_timer(line_pause).timeout

		# Randomize the lyric label location to spice it up
		var rand_x = randf_range(-2, 2)
		var rand_y = randf_range(5, 7)
		lyric_label.position = Vector3(rand_x, rand_y, 0)

func display_line(line: String) -> void:
	var words = line.split(" ")
	lyric_label.text = ""
	for word in words:
		if lyric_label:
			lyric_label.text += (word + " ")
		await get_tree().create_timer(word_delay).timeout

func _turn_towards_target(speed: float, delta: float) -> void:
	if not GameManager.player:
		return
	var direction: Vector3 = self.global_position.direction_to(GameManager.player.global_position)
	self.rotation.y = lerp_angle(
		self.rotation.y, atan2(
			- direction.x, -direction.z
		),
		delta * speed
	)
