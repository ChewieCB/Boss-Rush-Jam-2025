extends MarginContainer
class_name LuckBar

signal show
signal hide

@export_category("Components")
@export var luck_component: LuckComponent

@export var timer: Timer
@export var luck_bar: TextureProgressBar
@export var luck_gain_bar: TextureProgressBar
#@onready var luck_modifier_sign_label: Label = $HBoxContainer/MarginContainer2/HBoxContainer/SignLabel
#@onready var luck_modifier_label: Label = $HBoxContainer/MarginContainer2/HBoxContainer/LuckModifierText
#@export var luck_modifier_text_lifetime: float = 2.0


func _ready() -> void:
	await get_owner().ready
	#LuckHandler.modifier_message.connect(show_luck_modifier)


func init_luck_ui(_luck, _max_luck) -> void:
	luck_bar.max_value = _max_luck
	luck_bar.value = _luck
	luck_gain_bar.max_value = _max_luck
	luck_gain_bar.value = _luck


#func show_luck_modifier(text: String, is_gain: bool = true) -> void:
	#luck_modifier_sign_label.text = "+" if is_gain else "-"
	#luck_modifier_label.text = text
	#await get_tree().create_timer(luck_modifier_text_lifetime).timeout
	#luck_modifier_sign_label.text = ""
	#luck_modifier_label.text = ""


func _on_luck_changed(new_luck: float, prev_luck: float) -> void:	
	if new_luck < prev_luck:
		luck_bar.value = new_luck
	else:
		luck_gain_bar.value = new_luck
	
	timer.start()


func _on_luck_maxed() -> void:
	pass


func cash_in_luck() -> void:
	pass


func _on_timer_timeout():
	luck_bar.value = luck_component.current_luck
	luck_gain_bar.value = luck_component.current_luck
