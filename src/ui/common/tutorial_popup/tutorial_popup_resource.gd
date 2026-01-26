extends Resource
class_name TutorialPopupResource

@export var trigger_on_spawn: bool = false
@export var one_shot: bool = true
@export var header_text: String
@export var body_items: Array[String]
@export var close_trigger_actions: Array[String]
@export var close_trigger_count: int = 1
@export var timeout: float = 0.0
@export var timeout_on_close: bool = false
