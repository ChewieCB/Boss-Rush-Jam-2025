extends Control

@onready var reroll_label: Label = $VBoxContainer/HBoxContainer/Label
@onready var reroll_cost_label: Label = $VBoxContainer/HBoxContainer/CostLabel
@onready var progress_bar: ProgressBar = $VBoxContainer/ProgressBar
@onready var progress_label: Label = $VBoxContainer/ProgressBar/Label

@export_group("Progress Animation")
@export var fill_time: float = 0.1



func _ready() -> void:
	progress_bar.value_changed.connect(_on_progress_changed)
	_update_reroll_max(GameManager.reroll_cost)
	GameManager.currency_changed.connect(_on_currency_changed)
	GameManager.reroll_cost_changed.connect(_update_reroll_max)
	GameManager.free_rerolls.connect(_on_free_rerolls)


func _on_progress_changed(value: float) -> void:
	progress_label.text = "%s/%s" % [progress_bar.value, progress_bar.max_value]
	if value == progress_bar.max_value:
		progress_bar.modulate = Color.FOREST_GREEN
		reroll_label.modulate = Color.GOLD
		reroll_cost_label.modulate = Color.GOLD
	else:
		progress_bar.modulate = Color.WHITE
		reroll_label.modulate = Color.WHITE
		reroll_cost_label.modulate = Color.WHITE


func _on_currency_changed(new_value: int) -> void:
	var progress_tween: Tween = get_tree().create_tween()
	progress_tween.tween_property(progress_bar, "value", new_value, fill_time).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)


func _update_reroll_max(new_max: int) -> void:
	reroll_cost_label.text = "(%s)" % new_max
	progress_bar.max_value = float(new_max)
	var new_value: int = min(GameManager.player_currency, progress_bar.max_value)
	var progress_tween: Tween = get_tree().create_tween()
	progress_tween.tween_property(progress_bar, "value", new_value, fill_time).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	_on_progress_changed(0)


func _on_free_rerolls() -> void:
	progress_bar.value = progress_bar.max_value
	reroll_cost_label.text = "(Free)"
	progress_label.text = "Free"
	
	progress_bar.modulate = Color.FOREST_GREEN
	reroll_label.modulate = Color.GOLD
	reroll_cost_label.modulate = Color.GOLD
