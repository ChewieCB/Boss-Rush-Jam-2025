extends BossCore
class_name ChiptopedeSegment

signal damaged(damage: float)

@onready var mesh: MeshInstance3D = $Cylinder
@export var rotation_speed: float = 5.0


func _ready() -> void:
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)
	self.rotation.z = randf_range(0, 2*PI)


func _physics_process(delta: float) -> void:
	self.rotation.z += rotation_speed * delta


func _on_health_changed(new_health: float, prev_health: float) -> void:
	if new_health < prev_health:
		damaged.emit(prev_health - new_health)
