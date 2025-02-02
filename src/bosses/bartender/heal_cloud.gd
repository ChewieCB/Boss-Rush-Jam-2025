extends Node3D

@export var heal_amount_flat = 100

@onready var heal_pe: GPUParticles3D = $HealEffect
@onready var light: OmniLight3D = $OmniLight3D
@onready var sfx_player: AudioStreamPlayer3D = $SFXPlayer

var healed_bodies = []

func _ready() -> void:
	heal_pe.emitting = true
	sfx_player.play()
	var tween = self.create_tween()
	tween.tween_property(light, "light_energy", 0, 2)


func _on_heal_effect_finished() -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(sfx_player, "volume_db", linear_to_db(0.01), 0.5)
	await tween.finished
	sfx_player.stop()
	call_deferred("queue_free")


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		if body not in healed_bodies:
			healed_bodies.append(body)
			var health_component: HealthComponent = body.get_node("HealthComponent")
			if health_component:
				health_component.heal(heal_amount_flat)
