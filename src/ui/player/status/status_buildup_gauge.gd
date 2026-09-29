class_name StatusBuildupGauge
extends HBoxContainer

@export var fill_smoothing: float = 10.0

@export_group("Activate Pop")
@export var pop_scale: Vector2 = Vector2(1.25, 1.6)
@export var pop_in_duration: float = 0.1
@export var pop_out_duration: float = 0.4

@export_group("Active Breathing")
@export var breath_scale: Vector2 = Vector2(1.03, 0.85)
@export var breath_duration: float = 0.5

@onready var icon_rect: TextureRect = $Icon
@onready var progress_bar: TextureProgressBar = $TextureProgressBar
@onready var label: Label = $TextureProgressBar/Label

var buildup: StatusBuildupComponent
var target_ratio: float = 0.0
var display_ratio: float = 0.0
# Applied every frame since containers reset child scale on re-sort
var bar_scale: Vector2 = Vector2.ONE
var scale_tween: Tween


func _ready() -> void:
	visible = false


func _process(delta: float) -> void:
	progress_bar.pivot_offset = progress_bar.size / 2.0
	progress_bar.scale = bar_scale

	if is_equal_approx(display_ratio, target_ratio):
		return
	display_ratio = lerpf(display_ratio, target_ratio, 1.0 - exp(-fill_smoothing * delta))
	if absf(display_ratio - target_ratio) < 0.001:
		display_ratio = target_ratio
	_update_bar()


func bind(buildup_: StatusBuildupComponent) -> void:
	if buildup:
		buildup.progress_changed.disconnect(_on_progress_changed)
		buildup.triggered.disconnect(_on_triggered)
		buildup.ended.disconnect(_on_ended)
	buildup = buildup_
	if buildup.icon:
		icon_rect.texture = buildup.icon
	label.text = buildup.display_name
	progress_bar.tint_progress = buildup.gauge_color
	buildup.progress_changed.connect(_on_progress_changed)
	buildup.triggered.connect(_on_triggered)
	buildup.ended.connect(_on_ended)
	set_progress(buildup.get_progress(), true)


func set_progress(ratio: float, instant: bool = false) -> void:
	target_ratio = clampf(ratio, 0.0, 1.0)
	if instant:
		display_ratio = target_ratio
	_update_bar()


func _update_bar() -> void:
	progress_bar.value = display_ratio * progress_bar.max_value
	visible = display_ratio > 0.0 or target_ratio > 0.0


func _new_scale_tween() -> Tween:
	if scale_tween:
		scale_tween.kill()
	scale_tween = create_tween()
	return scale_tween


func _on_triggered() -> void:
	var tween := _new_scale_tween()
	tween.tween_property(self, "bar_scale", pop_scale, pop_in_duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "bar_scale", Vector2.ONE, pop_out_duration) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_start_breathing)


func _start_breathing() -> void:
	var tween := _new_scale_tween().set_loops()
	tween.tween_property(self, "bar_scale", breath_scale, breath_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "bar_scale", Vector2.ONE, breath_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_ended() -> void:
	var tween := _new_scale_tween()
	tween.tween_property(self, "bar_scale", Vector2.ONE, 0.15)


func _on_progress_changed(ratio: float, _active: bool) -> void:
	set_progress(ratio)
