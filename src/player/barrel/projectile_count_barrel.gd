extends SpinBarrelInterface

## This should have same length as `text_possible_values`
## (which is declared in base script and can be edited as exported variable)
@export var enum_possible_values: Array[PossibleValueEnum] = []

enum PossibleValueEnum {
	NONE,
	REDUCE_FLAT_1_PROJECTILE,
	REDUCE_FLAT_2_PROJECTILE,
	REDUCE_PERC_25_PROJECTILE,
	REDUCE_PERC_50_PROJECTILE,
	REDUCE_PERC_100_PROJECTILE,
	ADD_FLAT_1_PROJECTILE,
	ADD_FLAT_2_PROJECTILE,
	ADD_FLAT_3_PROJECTILE,
	ADD_PERC_25_PROJECTILE,
	ADD_PERC_50_PROJECTILE,
	ADD_PERC_100_PROJECTILE,
}

func _ready() -> void:
	super()
	if len(enum_possible_values) != len(text_possible_values):
		print("[Error] Different length of barrel possible values in {0}".format([barrel_name]))

func on_prepare_to_fire():
	super()
	print("on_prepare_to_fire on {0}".format([name]))
	match enum_possible_values[chosen_id]:
		PossibleValueEnum.REDUCE_FLAT_1_PROJECTILE:
			owner_gun.modified_projectile_amount -= 1
		PossibleValueEnum.REDUCE_FLAT_2_PROJECTILE:
			owner_gun.modified_projectile_amount -= 2
		PossibleValueEnum.REDUCE_PERC_25_PROJECTILE:
			owner_gun.modified_projectile_amount = round(owner_gun.modified_projectile_amount * 0.75)
		PossibleValueEnum.REDUCE_PERC_50_PROJECTILE:
			owner_gun.modified_projectile_amount = round(owner_gun.modified_projectile_amount * 0.50)
		PossibleValueEnum.REDUCE_PERC_100_PROJECTILE:
			owner_gun.modified_projectile_amount = round(owner_gun.modified_projectile_amount * 0)
		PossibleValueEnum.ADD_FLAT_1_PROJECTILE:
			owner_gun.modified_projectile_amount += 1
		PossibleValueEnum.ADD_FLAT_2_PROJECTILE:
			owner_gun.modified_projectile_amount += 2
		PossibleValueEnum.ADD_FLAT_3_PROJECTILE:
			owner_gun.modified_projectile_amount += 3
		PossibleValueEnum.ADD_PERC_25_PROJECTILE:
			owner_gun.modified_projectile_amount = round(owner_gun.modified_projectile_amount * 1.25)
		PossibleValueEnum.ADD_PERC_50_PROJECTILE:
			owner_gun.modified_projectile_amount = round(owner_gun.modified_projectile_amount * 1.5)
		PossibleValueEnum.ADD_PERC_100_PROJECTILE:
			owner_gun.modified_projectile_amount = round(owner_gun.modified_projectile_amount * 2)
	print("projectile: {0}".format([owner_gun.modified_projectile_amount]))
	modification_completed.emit()


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