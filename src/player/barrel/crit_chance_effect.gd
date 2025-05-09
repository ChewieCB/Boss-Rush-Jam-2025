extends BaseBarrelEffect

# Crit are rolled separately, therefore it is possible for triple crit
# (1 from each barrel), result in 800% damage (200 -> 400 -> 800)

## In %, so 50 = 50%
@export var crit_chance: float = 25

const CRIT_MULTIPLIER = 2.0

func on_damage_calculation():
	super ()
	var roll = randi_range(1, 100)
	if roll <= crit_chance:
		owner_barrel.owner_gun.modified_damage = int(owner_barrel.owner_gun.modified_damage * CRIT_MULTIPLIER)
		owner_barrel.owner_gun.crit_damage(owner_barrel.owner_gun.modified_damage)