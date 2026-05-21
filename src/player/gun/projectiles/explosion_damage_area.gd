extends Area3D
class_name ExplosionDamageArea

signal explosive_damage(damage: float, target: CharacterBody3D)
signal finished

@onready var explosion_vfx: ExplosionParticles = $ExplosionVFX
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var sfx_player: AudioStreamPlayer3D = $SFXPlayer

const LINGERING_DURATION = 0.1

var active = false
var damage = 0
var damage_disabled = true
@export var damage_variance: float = 11.0

var infused_status_effects: Array[BossCore.BossStatusEffect] = []


func _ready():
	explosion_vfx.finished.connect(finished.emit)
	

func init(_damage: int):
	damage = _damage


func set_damage_radius(radius: float) -> void:
	var new_shape := SphereShape3D.new()
	new_shape.radius = radius
	collision_shape.shape = new_shape
	explosion_vfx.scale_factor = radius / 1.2  # Magic number - default area radius


func add_status_effect(status_effect: BossCore.BossStatusEffect) -> void:
	if not status_effect in infused_status_effects:
		infused_status_effects.append(status_effect)


func explode():
	if explosion_vfx.time_until_queue_free < LINGERING_DURATION:
		push_warning("Explosion VFX visible duration is less than damage hitbox duration!")
	
	SoundManager.play_sfx_guarded(sfx_player)
	if infused_status_effects:
		match infused_status_effects[-1]:
			BossCore.BossStatusEffect.BURNING:
				explosion_vfx.set_colour(Color.TOMATO)
			BossCore.BossStatusEffect.POISONED:
				explosion_vfx.set_colour(Color.DARK_GREEN)
			BossCore.BossStatusEffect.FROZEN:
				explosion_vfx.set_colour(Color.AQUA)
			BossCore.BossStatusEffect.SHOCKED:
				explosion_vfx.set_colour(Color.LIGHT_GOLDENROD)
			BossCore.BossStatusEffect.BLEEDING:
				explosion_vfx.set_colour(Color.DARK_RED)
	
	explosion_vfx.explode()
	get_tree().create_timer(LINGERING_DURATION).timeout.connect(
		func(): 
			damage_disabled = true
	)


func _on_body_entered(body: Node3D, is_disabled: bool = damage_disabled) -> void:
	if body is CharacterBody3D and not is_disabled:
		# Colour the damage text based on any elemental effects
		var text_colour: Color = Color.ORANGE
		for status_effect in infused_status_effects:
			match status_effect:
				BossCore.BossStatusEffect.BURNING:
					text_colour = Color.DARK_ORANGE
				BossCore.BossStatusEffect.POISONED:
					text_colour = Color.DARK_GREEN
				BossCore.BossStatusEffect.FROZEN:
					text_colour = Color.AQUA
				BossCore.BossStatusEffect.SHOCKED:
					text_colour = Color.YELLOW
				BossCore.BossStatusEffect.BLEEDING:
					text_colour = Color.DARK_RED
			
			if body.has_method("apply_status_buildup"):
				body.apply_status_buildup(status_effect, 10000)
		
		body.health_component.damage(damage, text_colour)
		explosive_damage.emit(damage, body)
		
		if body is Player:
			body.apply_impulse_to_player(global_position.direction_to(body.global_position) * damage)
			# TODO - negative luck from getting hit by your own AoE
		else:
			LuckHandler.accumulate_dps_dealt(damage)


func _on_area_entered(area: Area3D) -> void:
	var _parent = area.get_parent()
	if _parent is CharacterBody3D:
		_on_body_entered(_parent)


func activate() -> void:
	damage_disabled = false
	active = true
	
	self.set_deferred("monitoring", true)
	self.set_deferred("monitorable", true)
	collision_shape.disabled = false
	self.collision_mask = pow(2, 1 - 1) + pow(2, 2 - 1) + pow(2, 3 - 1) + pow(2, 4 - 1) + pow(2, 5 - 1) + pow(2, 7 - 1) + pow(2, 8 - 1)
	self.visible = true
	self.process_mode = Node.PROCESS_MODE_INHERIT
	explode.call_deferred()


func deactivate() -> void:
	if sfx_player.is_playing():
		await sfx_player.finished
	
	damage_disabled = true
	infused_status_effects = []
	explosion_vfx.reset_color()
	self.visible = false
	active = false
	
	self.set_deferred("monitoring", true)
	self.set_deferred("monitorable", true)
	self.collision_mask = 0
	collision_shape.set_deferred("disabled", false)
	self.process_mode = Node.PROCESS_MODE_DISABLED
