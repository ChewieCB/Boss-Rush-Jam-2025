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
	popup_expired.emit(self)
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
