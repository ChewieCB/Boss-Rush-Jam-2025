extends BaseTrigger
class_name BarrelEffectTrigger

signal triggered

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

@onready var icon_decal_1: Decal = $MeshInstance3D3/EffectIconDecal
@onready var icon_decal_2: Decal = $MeshInstance3D2/EffectIconDecal
@onready var icon_decal_3: Decal = $MeshInstance3D/EffectIconDecal
@onready var icon_decals = [icon_decal_1, icon_decal_2, icon_decal_3]


func _ready() -> void:
	super()
	current_effect_hit_count = 0


func hit_with_effect(installed_barrels: Array[SpinBarrel]) -> void:
	for barrel in installed_barrels:
		var current_effect = barrel.get_active_effect()
		if not current_effect in applied_effects:
			applied_effects.append(current_effect)
			current_effect_hit_count += 1
			
			icon_decals[current_effect.icon_id].modulate = Color(0, 100, 0)
			
			triggered.emit()


func _on_health_diff(diff: float) -> void:
	pass
	#current_dps_count += abs(diff)


func activate() -> void:
	super()


func _on_dps_window_timer_timeout() -> void:
	current_effect_hit_count = 0
