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
