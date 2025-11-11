extends BaseBarrelEffect

@export var degrade_firerate_perc: float = 50
@export var degrade_spread_perc: float = 100

const DEGRADE_RATE_BY_DAMAGE = 100.0

var is_active = false
var total_potential_damage = 0
var total_ammo_consumed = 0


func on_barrel_remove():
	is_active = false
	total_potential_damage = 0
	total_ammo_consumed = 0

func on_barrel_start_spin():
	is_active = false
	total_potential_damage = 0
	total_ammo_consumed = 0
	
func on_barrel_stop_spin():
	is_active = true
	total_potential_damage = 0
	total_ammo_consumed = 0

func on_reload_end():
	total_potential_damage = 0
	total_ammo_consumed = 0

func on_projectile_spawn(projectile: BaseBullet):
	super (projectile)
	total_potential_damage += projectile.damage

func on_ammo_consumed():
	super ()
	total_ammo_consumed += 1
	owner_barrel.owner_gun.magazine_ammo_left = clamp(owner_barrel.owner_gun.magazine_ammo_left + 1, 0, owner_barrel.owner_gun.modified_magazine_size)


func on_fire_rate_check():
	super ()
	owner_barrel.owner_gun.modified_firerate = calculate_new_value(
		owner_barrel.owner_gun.modified_firerate, -degrade_firerate_perc * (total_potential_damage / DEGRADE_RATE_BY_DAMAGE), true, false)

func on_prepare_to_fire():
	super ()
	owner_barrel.owner_gun.modified_spread_angle = calculate_new_value(
		owner_barrel.owner_gun.modified_spread_angle, degrade_spread_perc * (total_potential_damage / DEGRADE_RATE_BY_DAMAGE), true, false)