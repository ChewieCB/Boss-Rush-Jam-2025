class_name StatusBuildupGauge
extends HBoxContainer

@onready var icon_rect: TextureRect = $Icon
@onready var progress_bar: TextureProgressBar = $TextureProgressBar
@onready var label: Label = $TextureProgressBar/Label

var buildup: StatusBuildupComponent


func _ready() -> void:
	visible = false


func bind(buildup_: StatusBuildupComponent) -> void:
	if buildup:
		buildup.progress_changed.disconnect(_on_progress_changed)
	buildup = buildup_
	if buildup.icon:
		icon_rect.texture = buildup.icon
	label.text = buildup.display_name
	progress_bar.tint_progress = buildup.gauge_color
	buildup.progress_changed.connect(_on_progress_changed)
	set_progress(buildup.get_progress())


func set_progress(ratio: float) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	progress_bar.value = ratio * progress_bar.max_value
	visible = ratio > 0.0


func _on_progress_changed(ratio: float, _active: bool) -> void:
	set_progress(ratio)
