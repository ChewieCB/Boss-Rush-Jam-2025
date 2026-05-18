extends BaseBarrelEffect


func on_prepare_to_fire():
	super ()
	var roll = randi_range(1, 100)
	if roll <= 50:
		owner_barrel.owner_gun.modified_damage = calculate_new_value(
			owner_barrel.owner_gun.modified_damage, 100, true, true)
	else:
		owner_barrel.owner_gun.modified_damage = 0
