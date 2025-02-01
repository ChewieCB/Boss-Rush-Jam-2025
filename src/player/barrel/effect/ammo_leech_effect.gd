extends BaseBarrelEffect

## In %, so 50 = 50%
@export var refund_chance: float
@export var flat_damage_modify: int
## In %, so 50 = 50%
@export var perc_damage_modify: float

func on_damage_calculation():
	super()
	# print("on_damage_calculation with {0}".format([display_text]))
	owner_barrel.owner_gun.modified_damage += flat_damage_modify
	owner_barrel.owner_gun.modified_damage = round(owner_barrel.owner_gun.modified_damage * (1 + (perc_damage_modify / 100.0)))
	# print("damage: {0}".format([owner_barrel.owner_gun.modified_damage]))

func on_damage_applied(_has_pos: bool = false, _pos: Vector3 = Vector3.ZERO):
	super()
	var roll = randi_range(1, 100)
	# print("on_damage_applied with {0}, rolled {1}".format([display_text, roll]))
	if roll <= refund_chance:
		owner_barrel.owner_gun.magazine_ammo_left = clamp(0, owner_barrel.owner_gun.magazine_ammo_left + 1, owner_barrel.owner_gun.modified_magazine_size)
		owner_barrel.owner_gun.regain_ammo(1)
		# print("ammo refuned")
