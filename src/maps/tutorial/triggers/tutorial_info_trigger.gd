extends Area3D
class_name TutorialInfoTrigger

signal activate(header_text, body_text)

@export var trigger_on_spawn: bool = false
@export var one_shot: bool = true
@export var header_text: String
@export var body_text: String


func _ready() -> void:
	if trigger_on_spawn:
		activate.emit(header_text, body_text)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		activate.emit(header_text, body_text)
		if one_shot:
			self.queue_free()
