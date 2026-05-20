extends BaseBarrelEffect

@export var damage_to_heal_ratio: float = 100.0
@export var vfx_heal_orb_prefab: PackedScene

const MAX_STORED_HP = 100

var accumulated_damage = 0
var stored_heal = 0:
	set(value):
		if stored_heal != value:
			stored_heal = value
			add_buff_that_track_recover_amount()
		if stored_heal == 0:
			GameManager.player.remove_status_effect_by_name("medical_payout_stored_heal")

var heal_icon = preload("res://assets/sprite/status_icon/medical_payout.png")

func remove_effect():
	accumulated_damage = 0
	stored_heal = 0
	GameManager.player.remove_status_effect_by_name("medical_payout_stored_heal")

func on_damage_applied(damage: float, has_pos: bool = false, pos: Vector3 = Vector3.ZERO):
	super (damage, has_pos, pos)
	accumulated_damage += damage
	stored_heal = min(round(accumulated_damage / damage_to_heal_ratio), MAX_STORED_HP)
	if has_pos:
		var inst: ColoredOrb = vfx_heal_orb_prefab.instantiate()
		get_tree().get_root().add_child(inst)
		inst.set_orb_color(Color(0.3, 0.7, 0))
		inst.global_position = pos
		inst.homing_target = GameManager.player


func on_reload_start():
	GameManager.player_currency -= round(GameManager.player.health_component.current_health)

func on_barrel_start_spin():
	if stored_heal == MAX_STORED_HP:
		LuckHandler.check_discover_luck_trigger(LuckTriggerInfo.LuckTriggerIdEnum.MEDICAL_PAYOUT__PAYDAY)
		LuckHandler.increase_luck(12, "+12 Payday!")
	if stored_heal > 0:
		GameManager.player.health_component.heal(stored_heal)
		GameManager.player.player_ui.start_heal_flash()
	remove_effect()

func on_barrel_remove():
	remove_effect()

func on_barrel_stop_spin():
	remove_effect()

func on_player_damaged():
	accumulated_damage = 0
	stored_heal = 0

func add_buff_that_track_recover_amount():
	# Just to display the status UI, not actually do anything
	var status_effect = StatusEffect.new()
	status_effect.display_name = "Stored heal on reload"
	status_effect.status_code = "medical_payout_stored_heal"
	status_effect.modified_stat = StatusEffect.PlayerStatEnum.NONE
	status_effect.value = stored_heal
	status_effect.modify_type = StatusEffect.ModifyType.FLAT
	status_effect.duration = StatusEffect.INFINITE_DURATION
	status_effect.is_bad_effect = false
	status_effect.status_icon = heal_icon
	status_effect.show_value_on_ui = true
	GameManager.player.add_status_effect(status_effect)
