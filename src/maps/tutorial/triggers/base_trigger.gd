extends StaticBody3D
class_name BaseTrigger

@export var connected_object: Node3D
@onready var label: Label3D = $Label3D
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var health_component: HealthComponent = $HealthComponent


func _ready() -> void:
	health_component.health_diff.connect(_on_health_diff)


func tween_label_text(value: float):
	label.text = str(value)


func _on_health_diff(_diff: float) -> void:
	pass


func activate() -> void:
	label.modulate = Color.GREEN
	health_component.is_invincible = true
	
	if connected_object:
		connected_object.activate()
