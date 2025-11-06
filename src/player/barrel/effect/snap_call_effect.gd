extends BaseBarrelEffect

## When projectile speed less than this, it deal less dmg
## otherwise, deal more dmg
@export var speed_threshold: float = 50
## How much dmg projectile is modified depend on difference between this 
## and threshold, per godot's unit
@export var dmg_modify_perc_per_unit: float = 1
@export var dmg_modify_for_hitscan: float = 2.0

func on_before_damage_applied(_enemy: CharacterBody3D, projectile: BaseBullet):
	# If hitscan, just straight buff it
	if projectile.is_hitscan:
		projectile.damage = projectile.damage * dmg_modify_for_hitscan
		return
	var dist_diff = abs(speed_threshold - projectile.projectile_speed)
	var perc_changed = dist_diff * dmg_modify_perc_per_unit
	if projectile.projectile_speed < speed_threshold:
		perc_changed = - perc_changed
	projectile.damage = projectile.damage * (1 + perc_changed / 100)