extends Area3D
class_name TutorialInfoTrigger

signal activate(body_items, close_trigger_actions)

@export var trigger_on_spawn: bool = false
@export var one_shot: bool = true
@export var header_text: String
@export var body_items: Array[String]
@export var close_trigger_actions: Array[String]


func _ready() -> void:
	if trigger_on_spawn:
		activate.emit(body_items, close_trigger_actions)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		activate.emit(body_items, close_trigger_actions)
		if one_shot:
			self.queue_free()
