extends BaseBarrelEffect

func on_projectile_spawn(projectile: BaseBullet):
	projectile.switch_to_slowmo_bullet_trail()


func on_player_contact(_projectile: BaseBullet):
	const PASSTHROUGH_LUCK = 3
	LuckHandler.check_discover_luck_trigger(LuckTriggerInfo.LuckTriggerIdEnum.BULLET_TIME__PASSTHROUGH)
	LuckHandler.increase_luck(PASSTHROUGH_LUCK, "+3 Pass Through!")

func on_before_damage_applied(_enemy: CharacterBody3D, projectile: BaseBullet):
	super (_enemy, projectile)
	const FORESIGHT_FLIGHT_TIME = 2
	if projectile.life_time > FORESIGHT_FLIGHT_TIME:
		const FORESIGHT_BONUS_LUCK = 10
		LuckHandler.check_discover_luck_trigger(LuckTriggerInfo.LuckTriggerIdEnum.BULLET_TIME__FORESIGHT)
		LuckHandler.increase_luck(FORESIGHT_BONUS_LUCK, "+7 Foresight!")
