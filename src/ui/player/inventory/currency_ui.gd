extends Control

@export var is_static: bool = false

@onready var static_chip_icon: TextureRect = $MarginContainer/HBoxContainer/MarginContainer/StaticChipIcon
@onready var reroll_progress: Control = $MarginContainer/HBoxContainer/MarginContainer/RerollUI
@onready var currency_label: Label = $MarginContainer/HBoxContainer/MarginContainer2/CurrencyLabel

var _currency_tween: Tween

func _ready() -> void:
	static_chip_icon.visible = is_static
	reroll_progress.visible = !is_static
	currency_label.text = str(GameManager.player_currency)
	GameManager.currency_changed.connect(_on_currency_changed)


func _on_currency_changed(new_value: int) -> void:
	# Cancel old tween if still running
	if _currency_tween and _currency_tween.is_running():
		_currency_tween.kill()

	# Start new tween from current displayed value
	var old_value: int = int(currency_label.text)
	_currency_tween = create_tween()
	_currency_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_currency_tween.tween_method(tween_label_text, old_value, new_value, 0.2)

func tween_label_text(value: int):
	currency_label.text = str(value)
