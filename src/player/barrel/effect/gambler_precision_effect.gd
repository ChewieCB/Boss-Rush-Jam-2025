extends BaseBarrelEffect


# TODO: Possible rework into roll a dice from 1 to 6 and do something with crit dmg with it

## In %, so 50 = 50%
@export var crit_chance: float
## In %, so 50 = 50%
@export var jam_chance_if_missed: float

var hit_count = 0
var projectile_count = 0

func on_prepare_to_fire():
	super ()
	hit_count = 0
	projectile_count = 0

func on_projectile_destroyed(_hit_boss: bool):
	super (_hit_boss)
	projectile_count += 1
	# print("projectile_count {0}, modified_projectile_amount{1}".format([projectile_count, owner_barrel.owner_gun.modified_projectile_amount]))'
	
	# We only check for missed after all projectiles destroyed
	if projectile_count == owner_barrel.owner_gun.modified_projectile_amount:
		if hit_count <= 0:
			var roll = randi_range(1, 100)
			if roll <= jam_chance_if_missed:
				owner_barrel.owner_gun.jam_the_gun(2)


func on_projectile_spawn(projectile: BaseBullet):
	projectile.crit_chance += (crit_chance / 100.0)

func on_damage_applied(_damage: float, _has_pos: bool = false, _pos: Vector3 = Vector3.ZERO):
	super (_damage, _has_pos, _pos)
	hit_count += 1
