extends BaseBarrelEffect

## When projectile travelled distance less than this, it deal less dmg
## otherwise, deal more dmg
@export var distance_threshold: float = 15
## How much dmg projectile is modified depend on difference between this 
## and threshold, per godot's unit
@export var dmg_modify_perc_per_unit: float = 5

func on_before_damage_applied(_enemy: CharacterBody3D, projectile: BaseBullet):
	var dist_diff = abs(distance_threshold - projectile.travelled_distance)
	var perc_changed = dist_diff * dmg_modify_perc_per_unit
	if projectile.travelled_distance < distance_threshold:
		perc_changed = - perc_changed
	projectile.damage = projectile.damage * (1 + perc_changed / 100)
