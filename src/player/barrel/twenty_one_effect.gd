extends BaseBarrelEffect


enum TwentyOneEffectEnum {
	NONE,
	NEXT_SHOT_DAMAGE_MULT,
	HEAL_20_PERC_HP,
	ADD_BULLET_RICOCHET,
	ADD_BULLET_PROJECTILE_COUNT,
	# LOSE_20_PERC_CHIPS,
	# EXPLOSION_15_PERC_HP_NON_LETHAL,
}
var rolled_twenty_one_effect = TwentyOneEffectEnum.NONE
var twenty_one_found = false
var is_active = false

var twenty_one_icon = preload("res://assets/sprite/status_icon/twenty-one.png")

func on_barrel_remove():
	is_active = false
	twenty_one_found = false
	remove_status_effect()

func on_barrel_start_spin():
	is_active = false
	twenty_one_found = false
	remove_status_effect()

func on_barrel_stop_spin():
	is_active = true


func on_prepare_to_fire():
	super ()
	const ADD_RICOCHET_COUNT = 10
	if is_active and twenty_one_found and rolled_twenty_one_effect == TwentyOneEffectEnum.ADD_BULLET_RICOCHET:
		owner_barrel.owner_gun.modified_ricochet_count = calculate_new_value(
			owner_barrel.owner_gun.modified_ricochet_count, ADD_RICOCHET_COUNT, false, true)
		twenty_one_found = false
		remove_status_effect()

	const ADD_PROJECTILE_COUNT = 5
	if is_active and twenty_one_found and rolled_twenty_one_effect == TwentyOneEffectEnum.ADD_BULLET_PROJECTILE_COUNT:
		owner_barrel.owner_gun.modified_projectile_amount = calculate_new_value(
			owner_barrel.owner_gun.modified_projectile_amount, ADD_PROJECTILE_COUNT, false, true)
		twenty_one_found = false
		remove_status_effect()

func on_gun_damage_calculation():
	super ()
	const DMG_MULT = 10
	if is_active and twenty_one_found and rolled_twenty_one_effect == TwentyOneEffectEnum.NEXT_SHOT_DAMAGE_MULT:
		owner_barrel.owner_gun.modified_damage = round(owner_barrel.owner_gun.modified_damage * DMG_MULT)
		rolled_twenty_one_effect = TwentyOneEffectEnum.NONE
		twenty_one_found = false
		remove_status_effect()

func on_damage_applied(damage: float, _has_pos: bool = false, _pos: Vector3 = Vector3.ZERO):
	# Check for 21 damage
	if is_active and damage == 21:
		twenty_one_found = true
		roll_twenty_one_effect()

func on_ammo_consumed():
	# Check for 21 bullet left
	if is_active and owner_barrel.owner_gun.magazine_ammo_left == 21:
		twenty_one_found = true
		roll_twenty_one_effect()


func roll_twenty_one_effect():
	var enum_values = TwentyOneEffectEnum.values()
	enum_values.erase(TwentyOneEffectEnum.NONE) # remove NONE
	rolled_twenty_one_effect = enum_values[randi() % enum_values.size()]
	add_status_effect()
	resolve_quick_twenty_one_effect()


func resolve_quick_twenty_one_effect():
	if not is_active or not twenty_one_found:
		return

	if rolled_twenty_one_effect == TwentyOneEffectEnum.HEAL_20_PERC_HP:
		GameManager.player.health_component.heal(GameManager.player.health_component.max_health * 0.2)
		twenty_one_found = false


func add_status_effect():
	# Just to display the status UI, not actually do anything
	var duration = 0.5
	if rolled_twenty_one_effect in [
		TwentyOneEffectEnum.NEXT_SHOT_DAMAGE_MULT,
		TwentyOneEffectEnum.ADD_BULLET_RICOCHET
	]:
		duration = StatusEffect.INFINITE_DURATION
	var status_effect = StatusEffect.new()
	status_effect.display_name = "Found Twenty-One"
	status_effect.status_code = "found_twenty_one"
	status_effect.modified_stat = StatusEffect.PlayerStatEnum.NONE
	status_effect.modify_type = StatusEffect.ModifyType.FLAT
	status_effect.duration = duration
	status_effect.show_duration_ui = true
	status_effect.is_bad_effect = false
	status_effect.status_icon = twenty_one_icon
	GameManager.player.add_status_effect(status_effect)

func remove_status_effect():
	GameManager.player.remove_status_effect_by_name("found_twenty_one")