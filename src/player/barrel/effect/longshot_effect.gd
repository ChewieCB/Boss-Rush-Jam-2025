extends BaseBarrelEffect

## When projectile travelled distance less than this, it deal less dmg
## otherwise, deal more dmg
@export var distance_threshold: float = 12
## How much dmg projectile is modified depend on difference between this 
## and threshold, per godot's unit
@export var dmg_modify_perc_per_unit: float = 2.5
## Same as above, but when bullet travelled distance is past level's max distance threshold.
## Should be a lower number.
@export var dmg_modify_perc_per_unit_past_max: float = 1

# These are for luck trigger and balancing
const HIGH_TRAVEL_DISTANCE_THRESHOLD = 20
var max_travel_distance_threshold = 35

func on_before_damage_applied(_enemy: CharacterBody3D, projectile: BaseBullet):
	# Change the threshold based on boss level
	match (GameManager.selected_boss_id):
		BossCore.BossIdEnum.BARTENDER:
			max_travel_distance_threshold = 30
		BossCore.BossIdEnum.SLOTS:
			max_travel_distance_threshold = 45
		BossCore.BossIdEnum.CHIPS:
			max_travel_distance_threshold = 60

	var perc_changed: float
	if projectile.travelled_distance > max_travel_distance_threshold:
		var normal_dist_diff = max_travel_distance_threshold - distance_threshold
		var past_max_dist_diff = projectile.travelled_distance - max_travel_distance_threshold
		perc_changed = normal_dist_diff * dmg_modify_perc_per_unit + past_max_dist_diff * dmg_modify_perc_per_unit_past_max
	else:
		var dist_diff = abs(distance_threshold - projectile.travelled_distance)
		perc_changed = dist_diff * dmg_modify_perc_per_unit
		if projectile.travelled_distance < distance_threshold:
			perc_changed = - perc_changed
	projectile.damage += round(projectile.damage * (perc_changed / 100))

	if projectile.travelled_distance >= HIGH_TRAVEL_DISTANCE_THRESHOLD:
		LuckHandler.check_discover_luck_trigger(LuckTriggerInfo.LuckTriggerIdEnum.LONG_SHOT__HIGH_DISTANCE)
		if projectile.travelled_distance >= max_travel_distance_threshold:
			LuckHandler.increase_luck(12, "+12 Extra Long!", LuckHandler.LuckTriggerType.RARE)
		else:
			LuckHandler.increase_luck(5, "+5 Long Shot!")
