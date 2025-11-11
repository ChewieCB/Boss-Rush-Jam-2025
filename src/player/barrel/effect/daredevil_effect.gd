extends BaseBarrelEffect

@export var bonus_dmg_perc_per_sec: float = 10
@export var max_bonus_cap: float = 100
@export var min_minus_cap: float = -50
@export var min_distance_to_boss: float = 5
@export var tick_interval: float = 0.5

var timer: Timer
var current_damage_bonus: float = 0
var is_active = false

var attack_up_icon = preload("res://assets/sprite/status_icon/attack_up.png")
var attack_down_icon = preload("res://assets/sprite/status_icon/attack_down.png")

func _ready():
	if timer == null:
		timer = Timer.new()
		timer.wait_time = tick_interval
		timer.one_shot = false
		add_child(timer)
		timer.timeout.connect(calculate_bonus)
		
	await get_tree().process_frame
	await get_tree().process_frame
	if GameManager.player:
		GameManager.player.change_near_enemy_radius(min_distance_to_boss)


func on_barrel_remove():
	is_active = false
	timer.stop()

func on_barrel_start_spin():
	is_active = false
	timer.stop()

func on_barrel_stop_spin():
	is_active = true
	timer.start(tick_interval)

func on_gun_damage_calculation():
	super ()
	owner_barrel.owner_gun.modified_damage = round(owner_barrel.owner_gun.modified_damage * (1 + (current_damage_bonus / 100.0)))

func calculate_bonus():
	if not is_active:
		return

	if GameManager.player.enemy_near_counter > 0:
		current_damage_bonus += bonus_dmg_perc_per_sec * tick_interval
	else:
		current_damage_bonus -= bonus_dmg_perc_per_sec * tick_interval
	current_damage_bonus = clamp(current_damage_bonus, min_minus_cap, max_bonus_cap)
	create_and_add_status_effect()


func create_and_add_status_effect() -> void:
	# Just to display the status UI, not actually do anything
	if current_damage_bonus == 0:
		return

	const BONUS_DURATION = 0.05
	var status_effect = StatusEffect.new()
	status_effect.modified_stat = StatusEffect.PlayerStatEnum.NONE
	status_effect.value = current_damage_bonus
	status_effect.modify_type = StatusEffect.ModifyType.FLAT
	status_effect.duration = tick_interval + BONUS_DURATION
	status_effect.show_value_on_ui = true
	if current_damage_bonus > 0:
		status_effect.display_name = "Damage increased"
		status_effect.status_code = "daredevil_damage_increased"
		status_effect.is_bad_effect = false
		status_effect.status_icon = attack_up_icon
	else:
		status_effect.display_name = "Damage decreased"
		status_effect.status_code = "daredevil_damage_decreased"
		status_effect.is_bad_effect = true
		status_effect.status_icon = attack_down_icon

	GameManager.player.add_status_effect(status_effect)