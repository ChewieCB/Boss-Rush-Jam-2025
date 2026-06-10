extends BaseBarrelEffect

@export var tracked_luck_trigger_ids: Array[LuckTriggerInfo.LuckTriggerIdEnum]

var homing_skill_issue_solved_hit_count = 0
var total_gun_hit_from_this_mag = 0

func on_projectile_spawn(projectile: BaseBullet):
	if owner_barrel.owner_gun.magazine_ammo_left <= 1:
		projectile.misc_data["is_last_bullet"] = true

func on_before_damage_applied(enemy: CharacterBody3D, projectile: BaseBullet):
	super (enemy, projectile)

	if tracked_luck_trigger_ids.has(LuckTriggerInfo.LuckTriggerIdEnum.RICOCHET__RICOSHOT):
		if projectile.is_ricochet_shot:
			LuckHandler.check_discover_luck_trigger(LuckTriggerInfo.LuckTriggerIdEnum.RICOCHET__RICOSHOT)
			if enemy is Player:
				LuckHandler.increase_luck(1, "+1 Blunderico!", LuckHandler.LuckTriggerType.NEGATIVE)
			else:
				if projectile.time_ricochetted >= 10:
					LuckHandler.increase_luck(100, "+100 Ultra Ricoshot?", LuckHandler.LuckTriggerType.DEVIL)
				elif projectile.time_ricochetted >= 5:
					LuckHandler.increase_luck(20, "+20 Mega Ricoshot!!", LuckHandler.LuckTriggerType.RARE)
				elif projectile.time_ricochetted >= 3:
					LuckHandler.increase_luck(10, "+10 Super Ricoshot!!", LuckHandler.LuckTriggerType.RARE)
				else:
					LuckHandler.increase_luck(3, "+3 Ricoshot!")

	if tracked_luck_trigger_ids.has(LuckTriggerInfo.LuckTriggerIdEnum.HOMING__CURVED_SHOT):
		if projectile.homing_strength > 0:
			if projectile.homing_curved_degrees >= 30:
				LuckHandler.check_discover_luck_trigger(LuckTriggerInfo.LuckTriggerIdEnum.HOMING__CURVED_SHOT)
				LuckHandler.increase_luck(3, "+8 Curved Shot!")

	if tracked_luck_trigger_ids.has(LuckTriggerInfo.LuckTriggerIdEnum.HOMING__SKILL_ISSUE_SOLVED):
		if projectile.homing_strength > 0:
			homing_skill_issue_solved_hit_count += 1
			if "is_last_bullet" in projectile.misc_data and homing_skill_issue_solved_hit_count >= total_gun_hit_from_this_mag:
				LuckHandler.check_discover_luck_trigger(LuckTriggerInfo.LuckTriggerIdEnum.HOMING__SKILL_ISSUE_SOLVED)
				LuckHandler.increase_luck(20, "+20 Skill issue solved!")
				homing_skill_issue_solved_hit_count = 0

func on_reload_end():
	homing_skill_issue_solved_hit_count = 0
	total_gun_hit_from_this_mag = owner_barrel.owner_gun.modified_projectile_amount * owner_barrel.owner_gun.modified_magazine_size