extends BaseBarrelEffect

@export var status_effect: BossCore.BossStatusEffect
@export var flat_build_up_amount: float = 10
@export var build_up_from_damage_multiplier: float = 1
@export var change_color = false
@export var new_color: Color

func on_projectile_spawn(_projectile: BaseProjectile):
	if change_color:
		_projectile.change_bullet_color(new_color)
	

func on_before_damage_applied(enemy: CharacterBody3D, _projectile: BaseProjectile):
	if enemy.has_method("apply_status_buildup"):
		enemy.apply_status_buildup(status_effect, flat_build_up_amount)