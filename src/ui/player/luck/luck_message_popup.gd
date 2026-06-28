extends MarginContainer
class_name LuckMessagePopupUI

signal popup_expired(popup: LuckMessagePopupUI)

@onready var panel: PanelContainer = $PanelContainer
@onready var label: Label = $PanelContainer/MarginContainer/LuckModifierText
@onready var anim_player: AnimationPlayer = $PanelContainer/AnimationPlayer
@export var timer: Timer

@export var text: String
@export var lifetime: float
var count: int = 1


func set_luck_text_color(luck_type: LuckHandler.LuckTriggerType) -> void:
	# LuckTriggerType.NORMAL
	var _font_color = Color(1, 0.82, 0.31)
	var _font_shadow_color = Color(0.41, 0.3, 0)
	var _font_outline_color = Color(0.75, 0.55, 0.14)

	match luck_type:
		LuckHandler.LuckTriggerType.RARE:
			_font_color = Color(1.0, 0.48, 0.0)
			_font_shadow_color = Color(0.62, 0.34, 0.02)
			_font_outline_color = Color(1.0, 0.68, 0.16)
		LuckHandler.LuckTriggerType.NEGATIVE:
			_font_color = Color(0.78, 0.12, 0.16)
			_font_shadow_color = Color(0.32, 0.03, 0.05)
			_font_outline_color = Color(0.95, 0.32, 0.36)
		LuckHandler.LuckTriggerType.DEVIL:
			_font_color = Color(0.62, 0.08, 0.42)
			_font_shadow_color = Color(0.18, 0.0, 0.12)
			_font_outline_color = Color(0.82, 0.32, 0.62)

	label.add_theme_color_override("font_color", _font_color)
	label.add_theme_color_override("font_shadow_color", _font_shadow_color)
	label.add_theme_color_override("font_outline_color", _font_outline_color)


func show_popup() -> void:
	label.text = text
	var popup_tween := get_tree().create_tween()
	popup_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	# Transparency
	popup_tween.tween_property(
		panel, "modulate:a", 1.0, 0.2
	)
	# Position
	#var _cached_pos_y: float = self.position.y
	panel.position.y = -40.0
	popup_tween.parallel().tween_property(
		panel, "position:y", 0.0, 0.2
	)
	# Scale
	panel.scale = Vector2.ZERO
	popup_tween.parallel().tween_property(
		panel, "scale", Vector2(1.2, 1.2), 0.2
	)
	popup_tween.chain().tween_property(
		panel, "scale", Vector2(1.0, 1.0), 0.1
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

	await popup_tween.finished
	
	timer.start(lifetime)


func hide_popup() -> void:
	var popup_tween := get_tree().create_tween()
	popup_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	popup_tween.set_parallel(true)
	# Transparency
	popup_tween.tween_property(
		panel, "modulate:a", 0.0, 0.25
	)
	# Position
	popup_tween.parallel().tween_property(
		panel, "position:y", -40.0, 0.25
	)
	await popup_tween.finished


func remove_popup() -> void:
	popup_expired.emit(self )
	self.queue_free()


func change_count(value: int) -> void:
	timer.start(lifetime)
	count += value
	
	label.text = text
	if count > 1:
		label.text += " (x%s)" % [count]
	
	var popup_tween := get_tree().create_tween()
	popup_tween.chain().tween_property(
		panel, "scale", Vector2(1.2, 1.2), 0.1
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	popup_tween.chain().tween_property(
		panel, "scale", Vector2(1.0, 1.0), 0.2
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUINT)

	await popup_tween.finished


func _on_timer_timeout() -> void:
	#if count > 1:
		#change_count(-1)
		#return
	await hide_popup()
	remove_popup()
