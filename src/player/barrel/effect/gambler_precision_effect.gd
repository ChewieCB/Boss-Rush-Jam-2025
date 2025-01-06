extends BaseBarrelEffect

## In %, so 50 = 50%
@export var crit_chance: float
## In %, so 50 = 50%
@export var jam_chance_if_missed: float

var missed = false

func on_prepare_to_fire():
	super()

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
	if missed:
		var roll = randi_range(1, 100)
		if roll <= jam_chance_if_missed:
			owner_barrel.owner_gun.jam_the_gun(2)
	missed = false

func on_projectile_destroyed():
	super()

func on_damage_calculation():
	super()
	missed = true
	var roll = randi_range(1, 100)
	if roll <= crit_chance:
		owner_barrel.owner_gun.modified_damage = owner_barrel.owner_gun.modified_damage * 2

func on_damage_applied():
	super()
	missed = false

func on_enemy_killed():
	super()

func on_status_effect_tick():
	super()

func on_weapon_switched_to():
	super()