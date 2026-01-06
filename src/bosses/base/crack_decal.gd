extends Decal

@export var lifetime: float = 5
@export var fade_speed: float = 1
@export var glow_fade_speed: float = 10

@onready var timer: Timer = $Timer

func _ready() -> void:
	timer.start(lifetime)

func _process(delta: float) -> void:
	if modulate.a > 0:
		modulate.a -= fade_speed * delta
		if modulate.a < 0:
			modulate.a = 0

	if emission_energy > 0:
		emission_energy -= glow_fade_speed * delta
		if emission_energy < 0:
			emission_energy = 0


func _on_timer_timeout() -> void:
	queue_free()
