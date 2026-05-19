extends Control

@export var luck_popup_ui: PackedScene
@export var luck_popup_lifetime: float = 2.0

@onready var luck_popup_parent: VBoxContainer = $VBoxContainer
var active_luck_popups: Array[LuckMessagePopupUI] = []


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	LuckHandler.modifier_message.connect(_on_luck_message)


func _on_luck_message(message: String, _is_gain: bool, luck_type: LuckHandler.LuckTriggerType) -> void:
	# Check to see if we have an existing version of this message
	for popup in active_luck_popups:
		if popup.text == message:
			popup.change_count(1)
			return
	
	var _new_message_ui = luck_popup_ui.instantiate()
	
	luck_popup_parent.add_child(_new_message_ui)
	_new_message_ui.set_luck_text_color(luck_type)
	_new_message_ui.text = message
	_new_message_ui.lifetime = luck_popup_lifetime
	active_luck_popups.append(_new_message_ui)
	_new_message_ui.popup_expired.connect(
		func(popup): active_luck_popups.erase(popup)
	)
	
	_new_message_ui.show_popup()
