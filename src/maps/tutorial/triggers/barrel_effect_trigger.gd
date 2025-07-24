extends BaseTrigger
class_name BarrelEffectTrigger

var applied_effects = []
@export var target_effect_hit_count: int = 3
var current_effect_hit_count: int = 0:
	set(value):
		var old_value: int = int(current_effect_hit_count)
		current_effect_hit_count = value
		var tween = get_tree().create_tween()
		tween.tween_method(tween_label_text, old_value, current_effect_hit_count, 0.2) 
		if current_effect_hit_count >= target_effect_hit_count:
			activate()
			return


func _ready() -> void:
	super()
	current_effect_hit_count = 0


func hit_with_effect(installed_barrels: Array[SpinBarrel]) -> void:
	for barrel in installed_barrels:
		var current_effect = barrel.get_active_effect()
		if not current_effect in applied_effects:
			applied_effects.append(current_effect)
			current_effect_hit_count += 1


func _on_health_diff(diff: float) -> void:
	pass
	#current_dps_count += abs(diff)


func activate() -> void:
	super()


func _on_dps_window_timer_timeout() -> void:
	current_effect_hit_count = 0
