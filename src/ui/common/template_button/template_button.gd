extends BaseButton
class_name TemplateButton

var scale_factor = 1.1

func _ready():
	mouse_entered.connect(expand_button_size)
	mouse_exited.connect(return_button_size)
	focus_entered.connect(expand_button_size)
	focus_exited.connect(return_button_size)

func _process(_delta: float) -> void:
	pivot_offset = size / 2

func expand_button_size():
	if disabled:
		return
	var tween = self.create_tween()
	tween.tween_property(self, "scale", Vector2(scale_factor, scale_factor), 0.1)

func return_button_size():
	pivot_offset = size / 2
	var tween = self.create_tween()
	tween.tween_property(self, "scale", Vector2(1, 1), 0.1)
