extends BossCore
class_name BlackjackHand


@onready var dust_particle: GPUParticles3D = $HandDust
@onready var death_particles: GPUParticles3D = $DeathDust
@onready var explosion_particle = $DeathExplosion


func _ready() -> void:
	super()


func fake_destroy() -> void:
	spawn_dust()
	spawn_explosion()
	sprite.visible = false
	debug_mesh.visible = false
	self.collision_layer = 0
	self.collision_mask = 0
	hurtbox.monitoring = false


func reinstate() -> void:
	self.collision_layer = pow(2, 3-1)
	self.collision_mask = pow(2, 1-1) + pow(2, 2-1) + pow(2, 4-1) + pow(2, 5-1)
	hurtbox.monitoring = true
	sprite.visible = true
	debug_mesh.visible = true


func spawn_dust() -> void:
	dust_particle.restart()
	dust_particle.emitting = true

#func spawn_death_particles() -> void:
	#death_particles.emitting = true

func spawn_explosion() -> void:
	explosion_particle.explosion()
