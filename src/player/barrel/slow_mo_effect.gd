extends BaseBarrelEffect

func on_projectile_spawn(projectile: BaseBullet):
	projectile.switch_to_slowmo_bullet_trail()


func on_player_contact(projectile: BaseBullet):
	const PASSTHROUGH_LUCK = 3
	const MIN_LIFE_TIME = 0.1
	if projectile.life_time > MIN_LIFE_TIME and not ("passthrough_triggered" in projectile.misc_data):
		projectile.misc_data["passthrough_triggered"] = true
		LuckHandler.check_discover_luck_trigger(LuckTriggerInfo.LuckTriggerIdEnum.BULLET_TIME__PASSTHROUGH)
		LuckHandler.increase_luck(PASSTHROUGH_LUCK, "+3 Pass Through!")

func on_before_damage_applied(enemy: CharacterBody3D, projectile: BaseBullet):
	super (enemy, projectile)
	const FORESIGHT_FLIGHT_TIME = 2
	const RARE_FORESIGHT_FLIGHT_TIME = 4
	if projectile.life_time > RARE_FORESIGHT_FLIGHT_TIME:
		LuckHandler.check_discover_luck_trigger(LuckTriggerInfo.LuckTriggerIdEnum.BULLET_TIME__FORESIGHT)
		if enemy is Player:
			LuckHandler.increase_luck(5, "+5 Suisight?", LuckHandler.LuckTriggerType.NEGATIVE)
		else:
			LuckHandler.increase_luck(14, "+14 Great Foresight!!", LuckHandler.LuckTriggerType.RARE)
	elif projectile.life_time > FORESIGHT_FLIGHT_TIME:
		LuckHandler.check_discover_luck_trigger(LuckTriggerInfo.LuckTriggerIdEnum.BULLET_TIME__FORESIGHT)
		if enemy is Player:
			LuckHandler.increase_luck(5, "+5 Suisight?", LuckHandler.LuckTriggerType.NEGATIVE)
		else:
			LuckHandler.increase_luck(7, "+7 Foresight!")
