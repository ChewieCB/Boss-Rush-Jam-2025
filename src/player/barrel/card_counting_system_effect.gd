extends BaseBarrelEffect

@export var damage_modify_perc_per_stack: float = 10

var missed_shot_stack_count = 0
var hit_count = 0
var projectile_count = 0

var status_icon = preload("res://assets/sprite/status_icon/bullet.png")

# FIXME: Not work properly with fast firing weapon
# If the 2nd bullet is created before the 1st bullet destroyed, it wont care about the 1st bullet

func on_prepare_to_fire():
	super ()
	hit_count = 0
	projectile_count = 0


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
	
func on_damage_applied(_has_pos: bool = false, _pos: Vector3 = Vector3.ZERO):
	super ()
	hit_count += 1

func on_projectile_destroyed():
	super ()
	projectile_count += 1
	# We only check for missed after all projectiles destroyed
	if projectile_count == owner_barrel.owner_gun.modified_projectile_amount:
		if hit_count <= 0:
			missed_shot_stack_count += 1
			show_stack_count_ui_effect()

func on_damage_calculation():
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
	effect.show_duration_ui = false
	effect.status_icon = status_icon
	GameManager.player.add_status_effect(effect)