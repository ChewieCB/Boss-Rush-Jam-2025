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


	var high_travel_time_threshold = 1.5
	var max_travel_time_threshold = 2.5
	# Change the threshold based on boss level
	match (GameManager.selected_boss_id):
		BossCore.BossIdEnum.BARTENDER:
			max_travel_time_threshold = 2
		BossCore.BossIdEnum.SLOTS:
			max_travel_time_threshold = 3
		BossCore.BossIdEnum.CHIPS:
			max_travel_time_threshold = 4

	const EXTRA_TIME_FOR_ICBM = 3

	if projectile.life_time >= high_travel_time_threshold:
		LuckHandler.check_discover_luck_trigger(LuckTriggerInfo.LuckTriggerIdEnum.SLOW_ROLLER__HIGH_TRAVEL_TIME)
		if projectile.can_be_aim_guided and projectile.life_time >= max_travel_time_threshold + EXTRA_TIME_FOR_ICBM:
			LuckHandler.increase_luck(24, "+24 ICBM!", LuckHandler.LuckTriggerType.RARE)
		elif projectile.life_time >= max_travel_time_threshold:
			LuckHandler.increase_luck(16, "+16 Slowrollmaxxing!", LuckHandler.LuckTriggerType.RARE)
		else:
			LuckHandler.increase_luck(8, "+8 Slow Rolling!")
