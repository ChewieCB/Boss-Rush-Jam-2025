extends BaseBarrelEffect

@export var damage_reduction_perc: float = 50
@export var buff_duration_mult: float = 0.8

var shield_icon = preload("res://assets/sprite/status_icon/shield.png")


func on_reload_start():
	create_effect()

func on_barrel_remove():
	remove_effect()

func on_barrel_start_spin():
	remove_effect()


func create_effect():
	var status_effect = create_damage_reduction_effect()
	GameManager.player.add_status_effect(status_effect)

func remove_effect():
	GameManager.player.remove_status_effect_by_name("safety_fold_damage_reduction")


func create_damage_reduction_effect() -> StatusEffect:
	var damage_reduction_effect = StatusEffect.new()
	damage_reduction_effect.display_name = "Damage reduction"
	damage_reduction_effect.status_code = "safety_fold_damage_reduction"
	damage_reduction_effect.modified_stat = StatusEffect.PlayerStatEnum.DAMAGE_REDUCTION
	damage_reduction_effect.value = damage_reduction_perc
	damage_reduction_effect.modify_type = StatusEffect.ModifyType.FLAT
	damage_reduction_effect.duration = owner_barrel.owner_gun.modified_reload_time * buff_duration_mult
	damage_reduction_effect.status_icon = shield_icon
	damage_reduction_effect.is_bad_effect = false
	damage_reduction_effect.show_value_on_ui = false
	damage_reduction_effect.show_duration_ui = true
	return damage_reduction_effect