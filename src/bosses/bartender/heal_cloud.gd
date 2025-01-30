extends Node3D

@export var heal_amount_flat = 100

@onready var heal_pe: GPUParticles3D = $HealEffect
@onready var light: OmniLight3D = $OmniLight3D

var healed_bodies = []

func _ready() -> void:
	heal_pe.emitting = true
	var tween = self.create_tween()
	tween.tween_property(light, "light_energy", 0, 2)


func _on_heal_effect_finished() -> void:
	await get_tree().create_timer(0.5).timeout
	call_deferred("queue_free")


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		if body not in healed_bodies:
			healed_bodies.append(body)
			var health_component: HealthComponent = body.get_node("HealthComponent")
			if health_component:
				health_component.heal(heal_amount_flat)
