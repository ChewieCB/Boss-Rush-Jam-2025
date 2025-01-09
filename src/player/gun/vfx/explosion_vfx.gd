extends Node3D

@onready var fire: GPUParticles3D = $Fire
@onready var smoke: GPUParticles3D = $Smoke

var count = 0

func _ready() -> void:
	fire.finished.connect(check_count)
	smoke.finished.connect(check_count)
	smoke.emitting = true
	fire.emitting = true


func check_count():
	count += 1
	if count >= 2:
		call_deferred('queue_free')
