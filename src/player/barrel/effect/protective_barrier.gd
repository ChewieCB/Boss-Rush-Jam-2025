extends BaseBarrelEffect

@export var shield_barrier_prefab: PackedScene
@export var damage_reduction_perc: float = 25

var shield_barrier_inst = null

func create_effect():
	if shield_barrier_inst == null:
		var status_effect = create_damage_reduction_effect()
		GameManager.player.add_status_effect(status_effect)
		shield_barrier_inst = shield_barrier_prefab.instantiate()
		GameManager.player.add_child(shield_barrier_inst)


func remove_effect():
	if shield_barrier_inst != null:
		shield_barrier_inst.queue_free()
		GameManager.player.remove_status_effect_by_name("protective_barrier_damage_reduction")

func on_barrel_remove():
	remove_effect()

func on_barrel_start_spin():
	remove_effect()

func on_barrel_stop_spin():
	create_effect()

func create_damage_reduction_effect() -> StatusEffect:
	var damage_reduction_effect = StatusEffect.new()
	damage_reduction_effect.display_name = "Damage reduction"
	damage_reduction_effect.status_code = "protective_barrier_damage_reduction"
	damage_reduction_effect.modified_stat = StatusEffect.PlayerStatEnum.DAMAGE_REDUCTION
	damage_reduction_effect.value = damage_reduction_perc
	damage_reduction_effect.modify_type = StatusEffect.ModifyType.FLAT
	damage_reduction_effect.duration = StatusEffect.INFINITE_DURATION
	damage_reduction_effect.is_bad_effect = false
	damage_reduction_effect.show_value_on_ui = false
	damage_reduction_effect.show_duration_ui = true
	return damage_reduction_effect