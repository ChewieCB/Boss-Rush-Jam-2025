extends BaseBarrelEffect

## When projectile lifetime less than this, it deal less dmg
@export var lifetime_threshold: float = 0.4
## How much dmg projectile is modified depend on difference between this 
## and threshold, per second
@export var dmg_modify_perc_per_sec: float = 100

func on_before_damage_applied(_enemy: CharacterBody3D, projectile: BaseBullet):
	var dist_diff = abs(lifetime_threshold - projectile.life_time)
	var perc_changed = dist_diff * dmg_modify_perc_per_sec
	if projectile.life_time < lifetime_threshold:
		perc_changed = - perc_changed
	projectile.damage += round(projectile.damage * (perc_changed / 100))

	const TRAVEL_TIME_THRESHOLD = 6

	if projectile.life_time >= TRAVEL_TIME_THRESHOLD:
		LuckHandler.check_discover_luck_trigger(LuckTriggerInfo.LuckTriggerIdEnum.SLOW_ROLLER__HIGH_TRAVEL_TIME)
		LuckHandler.increase_luck(10, "+10 Slow Rolling!")
