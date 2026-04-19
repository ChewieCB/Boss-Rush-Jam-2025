extends StaticBody3D

@onready var omni_light: OmniLight3D = $OmniLight3D
@onready var health_component = $HealthComponent

func _on_health_component_died() -> void:
	call_deferred("queue_free")

func toggle_light(is_on: bool):
	omni_light.visible = is_on