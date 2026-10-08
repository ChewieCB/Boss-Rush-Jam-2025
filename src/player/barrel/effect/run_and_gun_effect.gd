extends BaseBarrelEffect

# Focus goes from -1 (max penalty) to 1 (max bonus).
# Dashing or not looking at an enemy drains focus
# Keep looking at an enemy build focus

# max focus
@export var modify_perc_spread_focused: float
@export var modify_perc_damage_focused: float
# negative focus
@export var modify_perc_spread_unfocused: float
@export var modify_perc_damage_unfocused: float

@export var focus_lost_per_dash: float = 0.5
@export var focus_lost_per_second: float = 0.25
@export var recover_delay_after_dash: float = 0.5
# In second, time from -1 focus to 1 focus
@export var full_focus_charge_time: float = 6.0

# Tween the focus change after a dash so it smoother
const FOCUS_DROP_SPEED = 4.0

var target_focus = 0.0
var focus = 0.0
var time_since_dash = 0.0


func _process(delta: float) -> void:
	if owner_barrel == null:
		return

	if time_since_dash < recover_delay_after_dash:
		time_since_dash += delta

	if not is_looking_at_enemy():
		target_focus = max(target_focus - delta * focus_lost_per_second, -1.0)
	elif time_since_dash >= recover_delay_after_dash and full_focus_charge_time > 0:
		target_focus = min(target_focus + delta * 2.0 / full_focus_charge_time, 1.0)

	if focus > target_focus:
		focus = move_toward(focus, target_focus, delta * FOCUS_DROP_SPEED)
	else:
		focus = target_focus

func is_looking_at_enemy() -> bool:
	return GameManager.player.aim_assist_ray_boss_check.is_colliding()

func on_barrel_install():
	super()
	reset_focus()

func on_barrel_remove():
	super()
	reset_focus()

func on_dash_movement():
	super()
	target_focus = max(target_focus - focus_lost_per_dash, -1.0)
	time_since_dash = 0.0

func reset_focus():
	target_focus = 0.0
	focus = 0.0
	time_since_dash = 0.0

func get_focus_modifier(focused_value: float, unfocused_value: float) -> float:
	if focus >= 0:
		return focused_value * focus
	return unfocused_value * -focus

func on_prepare_to_fire():
	super()
	owner_barrel.owner_gun.modified_spread_angle = preview_spread_angle(owner_barrel.owner_gun.modified_spread_angle)

func preview_spread_angle(spread_angle: float) -> float:
	var modify_perc = get_focus_modifier(modify_perc_spread_focused, modify_perc_spread_unfocused)
	return round(spread_angle * (1 + modify_perc / 100.0))

func on_gun_damage_calculation():
	super()
	var modify_perc = get_focus_modifier(modify_perc_damage_focused, modify_perc_damage_unfocused)
	owner_barrel.owner_gun.modified_damage = round(owner_barrel.owner_gun.modified_damage * (1 + modify_perc / 100.0))
