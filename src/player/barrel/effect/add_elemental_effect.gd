extends BaseBarrelEffect

@export var status_effect: BossCore.BossStatusEffect
@export var flat_build_up_amount: float = 50 # Boss usually have 1000 resist
@export var build_up_from_damage_multiplier: float = 0.5
@export var change_color = false
@export var new_color: Color


func on_effect_set():
	var element: String
	match status_effect:
		BossCore.BossStatusEffect.BURNING:
			element = "fire"
		BossCore.BossStatusEffect.FROZEN:
			element = "cold"
		BossCore.BossStatusEffect.POISONED:
			element = "poison"
		BossCore.BossStatusEffect.SHOCKED:
			element = "electric"
	owner_barrel.owner_gun.set_elemental_anim(element)


func on_effect_removed():
	owner_barrel.owner_gun.remove_elemental_anim()


func on_barrel_start_spin():
	owner_barrel.owner_gun.remove_elemental_anim()


func on_projectile_spawn(_projectile: BaseBullet):
	if change_color:
		_projectile.change_bullet_color(new_color)
	_projectile.infuse_status_effect(status_effect)
	_projectile.applied_emitting_elemental_vfx(status_effect)


func on_before_damage_applied(enemy: CharacterBody3D, _projectile: BaseBullet):
	if enemy.has_method("apply_status_buildup"):
		var build_up_amount = flat_build_up_amount + _projectile.damage * build_up_from_damage_multiplier
		enemy.apply_status_buildup(status_effect, build_up_amount)
