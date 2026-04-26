extends StaticBody3D

@onready var omni_light: OmniLight3D = $OmniLight3D
@onready var health_component = $HealthComponent

@export var transition_duration: float = 1.0

var original_light_energy: float = 2.0
var _current_tween: Tween

func _ready() -> void:
	original_light_energy = omni_light.light_energy

func _on_health_component_died() -> void:
	call_deferred("queue_free")

func toggle_light(is_on: bool):
	if _current_tween:
		_current_tween.kill()
	
	_current_tween = create_tween()
	_current_tween.set_parallel(true)
	
	if is_on:
		omni_light.visible = true
		omni_light.light_energy = 0.0
		_current_tween.tween_property(omni_light, "light_energy", original_light_energy, transition_duration).set_trans(Tween.TRANS_SINE)
	else:
		_current_tween.tween_property(omni_light, "light_energy", 0.0, transition_duration).set_trans(Tween.TRANS_SINE)
		_current_tween.tween_callback(_set_light_visible_false)

func _set_light_visible_false() -> void:
	omni_light.visible = false