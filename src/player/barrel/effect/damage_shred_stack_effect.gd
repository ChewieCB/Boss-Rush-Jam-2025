extends BaseBarrelEffect

@export var flat_damage_bonus: int = 0
@export var perc_damage_bonus: float = 0

var stack_count = 0

func on_reload_start():
	super()
	stack_count = 0

func on_damage_applied(_has_pos: bool = false, _pos: Vector3 = Vector3.ZERO):
	super()
	stack_count += 1

func on_damage_calculation():
	super()
	owner_barrel.owner_gun.modified_damage += flat_damage_bonus * stack_count
	owner_barrel.owner_gun.modified_damage = round(owner_barrel.owner_gun.modified_damage * (1 + (perc_damage_bonus * stack_count / 100.0)))
