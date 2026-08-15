extends MarginContainer
class_name BossSubHealthBar

@export var label: Label
@export var health_bar: TextureProgressBar
@export var damage_bar: TextureProgressBar


func init_bars(_health: float) -> void:
	health_bar.max_value = _health
	health_bar.value = _health
	damage_bar.max_value = _health
	damage_bar.value = _health
	label.text = "%s/%s" % [health_bar.value, health_bar.max_value]


func anim_health_ui_scale(amount: float = 1.1, speed_scale: float = 1.0) -> void:
	UIUtils.anim_ui_elem_scale(self, amount, speed_scale)
