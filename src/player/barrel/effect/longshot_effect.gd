extends BaseBarrelEffect

## When projectile travelled distance less than this, it deal less dmg
## otherwise, deal more dmg
@export var distance_threshold: float = 12
## How much dmg projectile is modified depend on difference between this 
## and threshold, per godot's unit
@export var dmg_modify_perc_per_unit: float = 2.5

const HIGH_TRAVEL_DISTANCE_THRESHOLD = 20
var max_travel_distance_threshold = 35

# func on_projectile_spawn(projectile: BaseBullet):
# 	projectile.misc_data["longshot_distance_required"] = HIGH_TRAVEL_DISTANCE_THRESHOLD
# 	projectile.misc_data["longshot_barrel_vfx_node_name"] = "SparklingEffect"

func on_before_damage_applied(_enemy: CharacterBody3D, projectile: BaseBullet):
	var dist_diff = abs(distance_threshold - projectile.travelled_distance)
	var perc_changed = dist_diff * dmg_modify_perc_per_unit
	if projectile.travelled_distance < distance_threshold:
		perc_changed = - perc_changed
	projectile.damage += round(projectile.damage * (perc_changed / 100))

	# Change the threshold based on boss level
	match (GameManager.selected_boss_id):
		BossCore.BossIdEnum.BARTENDER:
			max_travel_distance_threshold = 30
		BossCore.BossIdEnum.SLOTS:
			max_travel_distance_threshold = 45
		BossCore.BossIdEnum.CHIPS:
			max_travel_distance_threshold = 60

	if projectile.travelled_distance >= HIGH_TRAVEL_DISTANCE_THRESHOLD:
		LuckHandler.check_discover_luck_trigger(LuckTriggerInfo.LuckTriggerIdEnum.LONG_SHOT__HIGH_DISTANCE)
		if projectile.travelled_distance >= max_travel_distance_threshold:
			LuckHandler.increase_luck(12, "+12 Extra Long!", LuckHandler.LuckTriggerType.RARE)
		else:
			LuckHandler.increase_luck(5, "+5 Long Shot!")
