extends BaseBarrelEffect

@export var split_count = 3
@export var split_spread_radius = 90.0

func on_projectile_impact(projectile: BaseBullet, _has_pos: bool = false, _pos: Vector3 = Vector3.ZERO):
	if not is_instance_valid(projectile):
		return
	projectile.split(split_count, split_spread_radius, _has_pos, _pos)


func on_before_damage_applied(enemy: CharacterBody3D, projectile: BaseBullet):
	super (enemy, projectile)
	if projectile.splitted:
		LuckHandler.check_discover_luck_trigger(LuckTriggerInfo.LuckTriggerIdEnum.SPLIT__SPLITSHOT)
		if enemy is Player:
			LuckHandler.increase_luck(1, "+1 Blundersplit", LuckHandler.LuckTriggerType.NEGATIVE)
		else:
			LuckHandler.increase_luck(3, "+3 Splitshot")