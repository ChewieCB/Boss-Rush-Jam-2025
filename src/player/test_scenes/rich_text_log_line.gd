extends RichTextLabel

const DELAY_BEFORE_FADE = 3

func _ready() -> void:
	await get_tree().create_timer(DELAY_BEFORE_FADE).timeout
	self_modulate = Color(1, 1, 1, 0.5)
