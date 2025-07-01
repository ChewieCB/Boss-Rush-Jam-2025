extends BaseBarrelEffect

@export var status_effect: BossCore.BossStatusEffect
@export var flat_build_up_amount: float = 10
@export var build_up_from_damage_multiplier: float = 1

func on_before_damage_applied(enemy: CharacterBody3D, _projectile: BaseProjectile):
	enemy.apply_status_buildup(status_effect, flat_build_up_amount)