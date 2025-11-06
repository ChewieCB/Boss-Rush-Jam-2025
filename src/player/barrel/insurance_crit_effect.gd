extends BaseBarrelEffect


var crit_down_icon = preload("res://assets/sprite/status_icon/crit_down.png")

var sure_crit = false

func on_barrel_remove():
	remove_effect()
	sure_crit = false

func on_barrel_start_spin():
	remove_effect()
	sure_crit = false


func on_barrel_stop_spin():
	create_effect()
	sure_crit = false


func on_projectile_destroyed(hit_boss: bool):
	if not hit_boss:
		sure_crit = true


func on_projectile_spawn(projectile: BaseBullet):
	if sure_crit:
		projectile.crit_chance = 100
		sure_crit = false


func create_effect():
	var status_effect = create_status_effect()
	GameManager.player.add_status_effect(status_effect)

func remove_effect():
	GameManager.player.remove_status_effect_by_name("critical_insurance_reduce_crit_dmg")


func create_status_effect() -> StatusEffect:
	var reduce_crit_dmg_effect = StatusEffect.new()
	reduce_crit_dmg_effect.display_name = "Reduce critical hit damage"
	reduce_crit_dmg_effect.status_code = "critical_insurance_reduce_crit_dmg"
	reduce_crit_dmg_effect.modified_stat = StatusEffect.PlayerStatEnum.CRITICAL_HIT_DAMAGE_MULTIPLIER
	reduce_crit_dmg_effect.value = -50
	reduce_crit_dmg_effect.modify_type = StatusEffect.ModifyType.PERCENTAGE
	reduce_crit_dmg_effect.duration = StatusEffect.INFINITE_DURATION
	reduce_crit_dmg_effect.is_bad_effect = true
	reduce_crit_dmg_effect.status_icon = crit_down_icon
	return reduce_crit_dmg_effect