extends StaticBody3D


@onready var health_component = $HealthComponent

func _on_health_component_died() -> void:
	call_deferred("queue_free")
