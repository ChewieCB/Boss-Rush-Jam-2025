extends BossCore
class_name ChiptopedeSegment

signal damaged(damage: float)

@onready var mesh: MeshInstance3D = $Cylinder
@export var rotation_speed: float = 5.0
@onready var splash_particles: GPUParticles3D = $SplashParticles
@onready var splash_ring_particles: GPUParticles3D = $SplashParticles/SplashRingParticle

var big_stack: BossChips


func _ready() -> void:
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)
	self.rotation.z = randf_range(0, 2*PI)


func _physics_process(delta: float) -> void:
	self.rotation.z += rotation_speed * delta


func _on_health_changed(new_health: float, prev_health: float) -> void:
	if new_health < prev_health:
		damaged.emit(prev_health - new_health)


# TODO - have elemental effects carry between small stacks and big stacks
func take_bleed_burst_damage() -> void:
	# Take 4% max hp damage and 100 flat damage
	const BLEED_DMG_MAX_HP_PERC = 0.04
	const BLEED_DMG_FLAT = 100
	var bleed_dmg = int(big_stack.health_component.max_health * BLEED_DMG_MAX_HP_PERC + BLEED_DMG_FLAT)
	health_component.damage(bleed_dmg, Color.DARK_RED)
	sprite.modulate = Color.DARK_RED
	await get_tree().create_timer(0.2).timeout
	sprite.modulate = Color.WHITE


func _on_burning_timer_timeout() -> void:
	const BURN_DMG_MAX_HP_PERC_PER_TICK = 0.003
	const BURN_DMG_FLAT_PER_TICK = 25
	# (0.3% max hp dmg per tick and flat 25)
	# With 20 ticks, 6% max hp and 500 flat damage
	var burn_dmg = int(big_stack.health_component.max_health * BURN_DMG_MAX_HP_PERC_PER_TICK + BURN_DMG_FLAT_PER_TICK)
	health_component.damage(burn_dmg, Color.ORANGE)
	sprite.modulate = Color.ORANGE
	await get_tree().create_timer(0.2).timeout
	sprite.modulate = Color.WHITE


func _on_poisoned_timer_timeout() -> void:
	const POISON_DMG_MAX_HP_PERC_PER_TICK = 0.02
	const POISON_DMG_FLAT_PER_TICK = 140
	# (2% max hp dmg per tick and flat 140)
	# With 4 ticks, 8% max hp and 560 flat damage
	var poison_dmg = int(big_stack.health_component.max_health * POISON_DMG_MAX_HP_PERC_PER_TICK + POISON_DMG_FLAT_PER_TICK)
	health_component.damage(poison_dmg, Color.WEB_GREEN)
	sprite.modulate = Color.WEB_GREEN
	await get_tree().create_timer(0.2).timeout
	sprite.modulate = Color.WHITE
