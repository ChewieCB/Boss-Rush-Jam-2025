extends MarginContainer
class_name LuckBar

signal show
signal hide

@export_category("Components")
@export var luck_component: LuckComponent

@export var timer: Timer
@export var luck_bar: TextureProgressBar
@export var luck_gain_bar: TextureProgressBar
@export var high_luck_mark_margin_ui: Control
@export var high_luck_glow: TextureRect
@export var luck_buff_container: Control
#@onready var luck_modifier_sign_label: Label = $HBoxContainer/MarginContainer2/HBoxContainer/SignLabel
#@onready var luck_modifier_label: Label = $HBoxContainer/MarginContainer2/HBoxContainer/LuckModifierText
#@export var luck_modifier_text_lifetime: float = 2.0


func _ready() -> void:
	await get_owner().ready
	_set_high_luck_glow_progress(0.0)
	GameManager.player_level_up.connect(update_high_luck_indicator)


func _set_high_luck_glow_progress(progress: float) -> void:
	high_luck_glow.material.set_shader_parameter("aura_progress", progress)
	high_luck_glow.material.set_shader_parameter("aura_colour:a", progress)


func init_luck_ui(_luck, _max_luck) -> void:
	luck_bar.max_value = _max_luck
	luck_bar.value = _luck
	luck_gain_bar.max_value = _max_luck
	luck_gain_bar.value = _luck
	# Wait to make sure the luckbar UI rescale properly
	await get_tree().process_frame
	await get_tree().process_frame
	update_high_luck_indicator()

func update_high_luck_indicator() -> void:
	# Map max luck to vertical line margin to indicate max luck left -> right
	var high_luck_threshold: float = luck_component.get_high_luck_threshold()
	high_luck_mark_margin_ui.get_node("HighLuckIndicator/MarginContainer/Label").text = "{0}%".format([high_luck_threshold * 100])
	var high_margin_l: float = high_luck_mark_margin_ui.size.x
	var high_luck_margin: float = remap(high_luck_threshold, 1.0, 0.0, 0.0, high_margin_l)
	high_luck_mark_margin_ui.add_theme_constant_override("margin_left", int(high_luck_margin))


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


func _on_high_luck_entered() -> void:
	# Animate luck bar glow
	var luck_glow_tween: Tween = get_tree().create_tween()
	luck_glow_tween.tween_method(
		_set_high_luck_glow_progress, 1.0, 0.0, 0.3
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CIRC)


func _on_high_luck_exited() -> void:
	# Animate luck bar dimming
	var luck_glow_tween: Tween = get_tree().create_tween()
	luck_glow_tween.tween_method(
		_set_high_luck_glow_progress, 0.0, 1.0, 0.3
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CIRC)
