extends Control

@onready var currency_label: Label = $MarginContainer/HBoxContainer/MarginContainer2/CurrencyLabel


func _ready() -> void:
	currency_label.text = str(GameManager.player_currency)
	GameManager.currency_changed.connect(_on_currency_changed)


func _on_currency_changed(new_value: int) -> void:
	var old_value: int = int(currency_label.text)
	var tween = get_tree().create_tween()
	tween.tween_method(tween_label_text, old_value, new_value, 0.2) 


func tween_label_text(value: int):
	currency_label.text = str(value)
