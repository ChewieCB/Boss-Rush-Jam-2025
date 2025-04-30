extends BossCore
class_name ChiptopedeSegment

signal damaged(damage: float)


func _ready() -> void:
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	pass


func _on_health_changed(new_health: float, prev_health: float) -> void:
	if new_health < prev_health:
		damaged.emit(prev_health - new_health)
