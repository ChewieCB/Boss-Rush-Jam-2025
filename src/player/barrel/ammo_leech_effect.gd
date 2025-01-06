extends BaseBarrelEffect

## In %, so 50 = 50%
@export var refund_chance: float
@export var flat_damage_modify: int
## In %, so 50 = 50%
@export var perc_damage_modify: float

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

func on_projectile_destroyed():
	super()

func on_damage_calculation():
	super()
	# print("on_damage_calculation with {0}".format([display_text]))
	owner_barrel.owner_gun.modified_damage += flat_damage_modify
	owner_barrel.owner_gun.modified_damage = round(owner_barrel.owner_gun.modified_damage * (1 + (perc_damage_modify / 100.0)))
	# print("damage: {0}".format([owner_barrel.owner_gun.modified_damage]))

func on_damage_applied():
	super()
	var roll = randi_range(1, 100)
	# print("on_damage_applied with {0}, rolled {1}".format([display_text, roll]))
	if roll <= refund_chance:
		owner_barrel.owner_gun.magazine_ammo_left += 1
		# print("ammo refuned")

func on_enemy_killed():
	super()

func on_status_effect_tick():
	super()

func on_weapon_switched_to():
	super()