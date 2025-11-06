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
    projectile.damage = projectile.damage * (1 + perc_changed / 100)