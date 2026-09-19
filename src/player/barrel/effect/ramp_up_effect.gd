extends BaseBarrelEffect

# Firerate ramps up based on how long trigger is held, not shots fired

# In percentage
@export var bonus_firerate_per_interval: float
# In second. Ex: 1 = bonus x firate per second
@export var interval_time: float
@export var is_perc: bool
# Same unit as bonus_firerate_per_interval
@export var max_bonus: float = 100.0

# @onready var luck_trigger_timer: Timer = $Timer

# Time after release before ramp start decaying
const RELEASE_GRACE_TIME = 0.35
const DECAY_RATE_MULTIPLIER = 2.0
const LUCK_TRIGGER_CHECK_INTERVAL = 1

var is_ramping_up = false
var ramp_progress = 0.0 # From 0 to 1
var release_timer = 0.0
var last_applied_delta = 0.0
var last_written_firerate = -1.0
var luck_trigger_timer = 0

func get_current_bonus() -> float:
	return min(floor(ramp_progress) * bonus_firerate_per_interval, max_bonus)


# Keep ramp while reloading/spinning (as long as player still hold down the trigger tho)
func is_ramp_frozen() -> bool:
	if owner_barrel == null:
		return false
	var gun = owner_barrel.owner_gun
	if gun == null:
		return false
	return gun.is_reloading or gun.is_spinning


func _process(delta: float) -> void:
	if owner_barrel == null or interval_time <= 0:
		return
	if is_ramp_frozen():
		release_timer = 0.0
		return
	if is_ramping_up:
		luck_trigger_timer += delta
		var max_progress = max_bonus / bonus_firerate_per_interval
		ramp_progress = min(ramp_progress + delta / interval_time, max_progress)
		if luck_trigger_timer >= LUCK_TRIGGER_CHECK_INTERVAL:
			luck_trigger_timer = 0
			if ramp_progress >= 1.0:
				LuckHandler.check_discover_luck_trigger(LuckTriggerInfo.LuckTriggerIdEnum.RAMP_UP__BULLET_HOSE)
				LuckHandler.increase_luck(+4, "+4 Bullet Hose")
		return
	if ramp_progress <= 0:
		return
	if release_timer < RELEASE_GRACE_TIME:
		release_timer += delta
		return


	ramp_progress = max(ramp_progress - delta / interval_time * DECAY_RATE_MULTIPLIER, 0.0)


func on_trigger_pulled():
	super()
	is_ramping_up = true
	release_timer = 0.0


func on_trigger_released():
	super()
	# Reload and spin also release trigger, so no reset ramp here
	is_ramping_up = false
	release_timer = 0.0


func on_fire_rate_check():
	super()
	var gun = owner_barrel.owner_gun
	# This get called every frame while holding, remove old bonus first so it don't stack
	if not is_equal_approx(gun.modified_firerate, last_written_firerate):
		last_applied_delta = 0.0
	var base_firerate = gun.modified_firerate - last_applied_delta
	var new_firerate = calculate_new_value(base_firerate, get_current_bonus(), is_perc, false)
	last_applied_delta = new_firerate - base_firerate
	gun.modified_firerate = new_firerate
	last_written_firerate = new_firerate


func on_barrel_start_spin():
	remove_effect()

func on_barrel_stop_spin():
	start_effect()

func remove_effect():
	luck_trigger_timer.stop()

func start_effect():
	luck_trigger_timer.start()


func _on_timer_timeout() -> void:
	pass # Replace with function body.
