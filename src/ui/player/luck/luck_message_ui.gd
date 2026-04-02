extends Control

@export var luck_popup_ui: PackedScene
@export var luck_popup_lifetime: float = 2.0

@onready var luck_popup_parent: VBoxContainer = $VBoxContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	LuckHandler.modifier_message.connect(_on_luck_message)


func _on_luck_message(message: String, _is_gain: bool) -> void:
	var _new_message_ui = luck_popup_ui.instantiate()
	luck_popup_parent.add_child(_new_message_ui)
	_new_message_ui.luck_popup(message, luck_popup_lifetime)
