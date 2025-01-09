extends BaseBarrelEffect

@export var bonus_firerate_per_interval: float
# In second. Ex: 1 = bonus x firate per second
@export var interval_time: float
@export var is_perc: bool

var is_ramping_up = false
var current_bonus_firerate = 0
var timer = 0
var original_firerate = 0

func _process(delta: float) -> void:
	if is_ramping_up:
		timer += delta
		if timer >= interval_time:
			timer = 0
			current_bonus_firerate += bonus_firerate_per_interval

func on_trigger_pulled():
	super()
	if not is_ramping_up:
		is_ramping_up = true
		original_firerate = owner_barrel.owner_gun.modified_firerate
		print("is_ramping_up TRUE")

func on_trigger_released():
	super()
	if is_ramping_up:
		is_ramping_up = false
		owner_barrel.owner_gun.modified_firerate = original_firerate
		current_bonus_firerate = 0
		timer = 0
		print("is_ramping_up FALSE")


func on_fire_rate_check():
	super()
	owner_barrel.owner_gun.modified_firerate = calculate_new_value(owner_barrel.owner_gun.modified_firerate, current_bonus_firerate, is_perc, false)
	print("new firerate {0} | current bonus {1}".format([snapped(owner_barrel.owner_gun.modified_firerate, 0.01), current_bonus_firerate]))

func on_reload_start():
	super()
	if is_ramping_up:
		is_ramping_up = false
		owner_barrel.owner_gun.modified_firerate = original_firerate
		current_bonus_firerate = 0
		timer = 0
		print("is_ramping_up FALSE")
