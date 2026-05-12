extends MarginContainer
class_name UIInputPrompt

@export var input_prompt: DeviceInputPrompt
@export var input_action: String:
	set(value):
		update_input_action(value)
@export var label: Label
@export var prompt_text: String:
	set(value):
		update_text(value)


func animate() -> void:
	if input_prompt.anim_tween:
		input_prompt.anim_tween.kill()
	input_prompt.animate()


func update_text(new_text: String) -> void:
	label.text = new_text


func update_input_action(new_action: String) -> void:
	input_prompt.assigned_action = new_action
