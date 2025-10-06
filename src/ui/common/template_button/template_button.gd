extends BaseButton
class_name TemplateButton

@export var default_hover_sfx = true
@export var default_focus_sfx = true
@export var scale_factor = 1.1

func _ready():
	mouse_entered.connect(expand_button_size)
	mouse_exited.connect(return_button_size)
	focus_entered.connect(expand_button_size)
	focus_exited.connect(return_button_size)

	if default_hover_sfx:
		mouse_entered.connect(_on_hover_play_sfx)

	if default_focus_sfx:
		focus_entered.connect(_on_focus_play_sfx)


func _process(_delta: float) -> void:
	pivot_offset = size / 2

func expand_button_size():
	pivot_offset = size / 2
	if disabled:
		return
	var tween = self.create_tween()
	tween.tween_property(self, "scale", Vector2(scale_factor, scale_factor), 0.1)

func return_button_size():
	pivot_offset = size / 2
	var tween = self.create_tween()
	tween.tween_property(self, "scale", Vector2(1, 1), 0.1)

func _on_focus_play_sfx():
	SoundManager.play_button_hover_sfx()

func _on_hover_play_sfx():
	SoundManager.play_button_hover_sfx()


func get_signal_connection_count(emitter: Object, signal_name: String) -> int:
	var connections = emitter.get_signal_connection_list(signal_name)
	return connections.size()


func set_text_color(color: Color):
	add_theme_color_override("font_disabled_color", color)
	add_theme_color_override("font_color", color)
	add_theme_color_override("font_pressed_color", color)
	add_theme_color_override("font_hover_color", color)
	add_theme_color_override("font_hover_pressed_color", color)
	add_theme_color_override("font_focus_color", color)
