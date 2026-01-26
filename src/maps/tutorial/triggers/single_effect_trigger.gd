extends StaticBody3D
class_name SingleEffectTrigger

signal triggered

var applied_effects = []
@export var target_effect: BarrelDataResource
@export var target_effect_id: int
@export var health_component: HealthComponent

@export var connected_object: Node3D
@export var active: bool = true


func hit_with_effect(installed_barrels: Array[SpinBarrel]) -> void:
	if active:
		for barrel in installed_barrels:
			var current_effect = barrel.get_active_effect()
			if current_effect.icon_id == target_effect_id:
				triggered.emit()
				activate()
				active = false


func activate() -> void:
	if active:
		if connected_object:
			connected_object.activate()
