extends BaseBarrelEffect

@export var flat_damage_bonus: int = 0
@export var perc_damage_bonus: float = 0

var stack_count = 0

var buff_icon = preload("res://assets/sprite/buff_icon/tag_n_shred.png")

func remove_effect():
	stack_count = 0
	GameManager.player.remove_status_effect_by_name("tag_n_shred_stack")

func on_damage_applied(_has_pos: bool = false, _pos: Vector3 = Vector3.ZERO):
	super ()
	stack_count += 1
	add_buff_that_track_stack_count()

func on_damage_calculation():
	super ()
	owner_barrel.owner_gun.modified_damage += flat_damage_bonus * stack_count
	owner_barrel.owner_gun.modified_damage = round(owner_barrel.owner_gun.modified_damage * (1 + (perc_damage_bonus * stack_count / 100.0)))

func on_reload_start():
	remove_effect()

func on_reload_end():
	remove_effect()

func on_barrel_remove():
	remove_effect()

func on_barrel_start_spin():
	remove_effect()

func on_barrel_stop_spin():
	remove_effect()

func add_buff_that_track_stack_count():
	# Just to display the status UI, not actually do anything
	var status_effect = StatusEffect.new()
	status_effect.display_name = "Tag n Shred stack"
	status_effect.status_code = "tag_n_shred_stack"
	status_effect.modified_stat = StatusEffect.PlayerStatEnum.NONE
	status_effect.value = stack_count
	status_effect.modify_type = StatusEffect.ModifyType.FLAT
	status_effect.duration = StatusEffect.INFINITE_DURATION
	status_effect.is_bad_effect = false
	status_effect.status_icon = buff_icon
	status_effect.show_value_on_ui = true
	GameManager.player.add_status_effect(status_effect)