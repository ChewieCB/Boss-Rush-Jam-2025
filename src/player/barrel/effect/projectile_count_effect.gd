extends BaseBarrelEffect

## Minimal projectile count is 0 even if you -1000
@export var flat_amount: int
## In %, so 50 = 50%
@export var perc_amount: float
## Set directly the amount of projectile (only work if `set_amount` > 0).
@export var set_amount: int

func on_prepare_to_fire():
	super()
	# print("on_prepare_to_fire with {0}".format([display_text]))
	owner_barrel.owner_gun.modified_projectile_amount += flat_amount
	owner_barrel.owner_gun.modified_projectile_amount = round(owner_barrel.owner_gun.modified_projectile_amount * (1 + (perc_amount / 100.0)))
	if owner_barrel.owner_gun.modified_projectile_amount < 0:
		owner_barrel.owner_gun.modified_projectile_amount = 0

	if set_amount > 0:
		owner_barrel.owner_gun.modified_projectile_amount = set_amount
	# print("projectile: {0}".format([owner_barrel.owner_gun.modified_projectile_amount]))


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

func on_damage_calculation():
	super()

func on_damage_applied():
	super()

func on_enemy_killed():
	super()

func on_status_effect_tick():
	super()

func on_weapon_switched_to():
	super()