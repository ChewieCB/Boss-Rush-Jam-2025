extends Area3D
class_name TutorialInfoTrigger

signal activate(body_items, close_trigger_actions, close_trigger_count, timeout)

@export var trigger_on_spawn: bool = false
@export var one_shot: bool = true
@export var header_text: String
@export var body_items: Array[String]
@export var close_trigger_actions: Array[String]
@export var close_trigger_count: int = 1
@export var timeout: float = 0.


func _ready() -> void:
	if trigger_on_spawn:
		activate.emit(body_items, close_trigger_actions, close_trigger_count, timeout)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		activate.emit(body_items, close_trigger_actions, close_trigger_count, timeout)
		if one_shot:
			self.queue_free()
