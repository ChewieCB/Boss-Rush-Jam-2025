extends Control

@onready var progress_bar: TextureProgressBar = $ProgressBar
@onready var progress_label: Label = $Label
@onready var anim_player: AnimationPlayer = $AnimationPlayer

@export_group("Progress Animation")
@export var fill_time: float = 0.1


func _ready() -> void:
	progress_bar.value_changed.connect(_on_progress_changed)
	_update_reroll_max(GameManager.reroll_cost)
	GameManager.currency_changed.connect(_on_currency_changed)
	GameManager.reroll_cost_changed.connect(_update_reroll_max)
	GameManager.free_rerolls.connect(_update_reroll_max.bind(progress_bar.max_value))


func _on_progress_changed(value: float) -> void:
	if value >= progress_bar.max_value:
		progress_bar.tint_over.a = 255
		progress_label.modulate = Color.GOLD
		anim_player.play("spin")
	else:
		progress_bar.tint_over.a = 0
		progress_label.modulate = Color.WHITE
		anim_player.stop()


func _on_currency_changed(new_value: int) -> void:
	var progress_tween: Tween = get_tree().create_tween()
	progress_tween.tween_property(progress_bar, "value", new_value, fill_time).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)


func _update_reroll_max(new_max: int) -> void:
	progress_bar.max_value = float(new_max)
	var new_value: int
	if not GameManager.is_free_reroll:
		new_value = min(GameManager.player_currency, progress_bar.max_value)
		progress_label.text = "%s" % new_max
	else:
		new_value = int(progress_bar.max_value)
		progress_label.text = "Free"
	var progress_tween: Tween = get_tree().create_tween()
	progress_tween.tween_property(progress_bar, "value", 0, fill_time * 4).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	progress_tween.chain().tween_property(progress_bar, "value", new_value, fill_time * 4).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	_on_progress_changed(0)
