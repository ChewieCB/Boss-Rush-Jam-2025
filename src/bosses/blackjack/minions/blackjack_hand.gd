extends BossCore
class_name BlackjackHand


@onready var dust_particle: GPUParticles3D = $HandDust


func _ready() -> void:
	super()


func fake_destroy() -> void:
	sprite.visible = false
	self.collision_layer = 0
	self.collision_mask = 0
	hurtbox.monitoring = false
	dust_particle.emitting = true
	await dust_particle.finished


func reinstate() -> void:
	self.collision_layer = pow(2, 3-1)
	self.collision_mask = pow(2, 1-1) + pow(2, 2-1) + pow(2, 4-1) + pow(2, 5-1)
	hurtbox.monitoring = true
	sprite.visible = true
