extends BaseBarrelEffect

@export var time_need_to_wait: float = 2
@export var stable_damage_modify_perc = 200
@export var stable_recoil_modify_perc = 100
@export var unstable_damage_modify_perc = -50
@export var unstable_spread_modify_perc = 100

var timer: Timer
var next_shot_is_powerful = false
var unstable_icon = preload("res://assets/sprite/status_icon/hourglass.png")

func _ready():
	if timer == null:
		timer = Timer.new()
		timer.wait_time = time_need_to_wait
		timer.one_shot = true
		add_child(timer)
		timer.timeout.connect(finished_waiting)

func finished_waiting():
	next_shot_is_powerful = true

func on_barrel_remove():
	remove_effect()

func on_barrel_start_spin():
	remove_effect()

func on_barrel_stop_spin():
	create_effect()

func on_prepare_to_fire():
	if next_shot_is_powerful:
		owner_barrel.owner_gun.modified_damage = calculate_new_value(
			owner_barrel.owner_gun.modified_damage, stable_damage_modify_perc, true, true)
		owner_barrel.owner_gun.modified_recoil = calculate_new_value(
			owner_barrel.owner_gun.modified_recoil, stable_recoil_modify_perc, true, false)
	else:
		owner_barrel.owner_gun.modified_damage = calculate_new_value(
			owner_barrel.owner_gun.modified_damage, unstable_damage_modify_perc, true, true)
		owner_barrel.owner_gun.modified_spread_angle = calculate_new_value(
			owner_barrel.owner_gun.modified_spread_angle, unstable_spread_modify_perc, true, false)

	next_shot_is_powerful = false
	create_effect()

	
func create_effect():
	timer.start()
	create_and_add_status_effect()

func remove_effect():
	timer.stop()
	GameManager.player.remove_status_effect_by_name("measured_shot_unstable_aim")

func create_and_add_status_effect() -> void:
	# Just to display the status UI, not actually do anything
	var status_effect = StatusEffect.new()
	status_effect.display_name = "Unstable Aim"
	status_effect.status_code = "measured_shot_unstable_aim"
	status_effect.modified_stat = StatusEffect.PlayerStatEnum.NONE
	status_effect.value = time_need_to_wait
	status_effect.modify_type = StatusEffect.ModifyType.FLAT
	status_effect.duration = time_need_to_wait + 0.1 # Add a bit of time to show UI better
	status_effect.is_bad_effect = true
	status_effect.status_icon = unstable_icon
	GameManager.player.add_status_effect(status_effect)
