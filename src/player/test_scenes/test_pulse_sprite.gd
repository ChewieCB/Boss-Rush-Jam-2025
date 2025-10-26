extends Node3D

@export var bpm: float = 120.0
@export var pulse_scale: float = 1.05 # max scale factor
@export var pulse_duration: float = 0.2 # how fast pulse animates (seconds)

@onready var sprite: Sprite3D = $Sprite3D

var _original_scale: Vector3
var _beat_timer: Timer
var _tween: Tween

func _ready():
    _original_scale = sprite.scale
    
    _beat_timer = Timer.new()
    _beat_timer.wait_time = 60.0 / bpm
    _beat_timer.autostart = true
    _beat_timer.one_shot = false
    _beat_timer.timeout.connect(_on_beat)
    add_child(_beat_timer)

func _on_beat():
    # Cancel previous tween if still playing
    if _tween and _tween.is_running():
        _tween.stop()
        sprite.scale = _original_scale

    _tween = create_tween()
    # Pulse out
    _tween.tween_property(sprite, "scale", _original_scale * pulse_scale, pulse_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    # Pulse back in
    _tween.tween_property(sprite, "scale", _original_scale, pulse_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
