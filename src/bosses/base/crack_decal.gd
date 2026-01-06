extends Decal

@export var glow: bool = false
@export var lifetime: float = 3
@export var glow_fade_speed: float = 5

@onready var timer: Timer = $Timer

func _ready() -> void:
	if glow:
		emission_energy = 1
	else:
		emission_energy = 0
	timer.start(lifetime)

func _process(delta: float) -> void:
	if emission_energy > 0:
		emission_energy -= glow_fade_speed * delta
		if emission_energy < 0:
			emission_energy = 0


func _on_timer_timeout() -> void:
	queue_free()
