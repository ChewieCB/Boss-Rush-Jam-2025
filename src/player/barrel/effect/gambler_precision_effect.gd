extends BaseBarrelEffect

## In %, so 50 = 50%
@export var crit_chance: float
## In %, so 50 = 50%
@export var jam_chance_if_missed: float

var hit_count = 0
var projectile_count = 0

func on_prepare_to_fire():
	super()
	hit_count = 0
	projectile_count = 0

func on_ammo_consumed():
	super()

func on_clip_empty():
	super()

func on_reload_start():
	super()

func on_reload_end():
	super()

func on_reload_interrupted():
	super()

func on_projectile_spawn():
	super()

func on_projectile_travel_tick():
	super()

func on_projectile_impact():
	super()


func on_projectile_destroyed():
	super()
	projectile_count += 1
	print("projectile_count {0}, modified_projectile_amount{1}".format([projectile_count, owner_barrel.owner_gun.modified_projectile_amount]))
	# We only check for missed after all projectiles destroyed
	if projectile_count == owner_barrel.owner_gun.modified_projectile_amount:
		if hit_count <= 0:
			# var roll = randi_range(1, 100)
			# if roll <= jam_chance_if_missed:
			owner_barrel.owner_gun.jam_the_gun(2)

func on_damage_calculation():
	super()
	var roll = randi_range(1, 100)
	if roll <= crit_chance:
		owner_barrel.owner_gun.modified_damage = owner_barrel.owner_gun.modified_damage * 2
		owner_barrel.owner_gun.crit_damage(owner_barrel.owner_gun.modified_damage)

func on_damage_applied():
	super()
	hit_count += 1

func on_enemy_killed():
	super()

func on_status_effect_tick():
	super()

func on_weapon_switched_to():
	super()
