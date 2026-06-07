extends BaseBarrelEffect

@export var damage_modify_perc_per_stack: float = 10

var missed_shot_stack_count = 0

var status_icon = preload("res://assets/sprite/status_icon/the_system.png")

# FIXME: Not work properly with fast firing weapon
# If the 2nd bullet is created before the 1st bullet destroyed, it wont care about the 1st bullet

func on_reload_start():
	super ()
	missed_shot_stack_count = 0
	GameManager.player.remove_status_effect_by_name("the_system_missed_stack_count")

func on_barrel_remove():
	missed_shot_stack_count = 0
	GameManager.player.remove_status_effect_by_name("the_system_missed_stack_count")

func on_barrel_start_spin():
	missed_shot_stack_count = 0
	GameManager.player.remove_status_effect_by_name("the_system_missed_stack_count")
	
func on_projectile_destroyed(_projectile: BaseBullet, hit_boss: bool):
	super (_projectile, hit_boss)
	if not hit_boss:
		missed_shot_stack_count += 1
		show_stack_count_ui_effect()

func on_gun_damage_calculation():
	super ()
	var sum_perc = damage_modify_perc_per_stack * missed_shot_stack_count
	owner_barrel.owner_gun.modified_damage = round(owner_barrel.owner_gun.modified_damage * (1 + (sum_perc / 100.0)))


func show_stack_count_ui_effect():
	# Just to display the value on status UI, not actually do anything
	var effect = StatusEffect.new()
	effect.display_name = "Damage increased"
	effect.status_code = "the_system_missed_stack_count"
	effect.modified_stat = StatusEffect.PlayerStatEnum.NONE
	effect.value = missed_shot_stack_count
	effect.modify_type = StatusEffect.ModifyType.FLAT
	effect.duration = StatusEffect.INFINITE_DURATION
	effect.is_bad_effect = false
	effect.show_value_on_ui = true
	effect.show_duration_ui = true
	effect.status_icon = status_icon
	GameManager.player.add_status_effect(effect)