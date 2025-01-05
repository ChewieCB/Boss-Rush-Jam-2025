extends Node3D
class_name SpinBarrelInterface

@export var barrel_name: String
## This should have same length as `enum_possible_values`
## (which will be declared separately in each barrel script)
@export var text_possible_values: Array[String] = []

@onready var display_label: Label3D = $Label3D

# Emit this signal after every hook to prevent race condition
signal modification_completed

var owner_gun: Gun
var spin_interval_timer = 0
var is_spinning = false
var chosen_id = 0

const SPIN_INTERVAL = 0.1

func _ready() -> void:
	instant_spin()

func start_spin():
	is_spinning = true

func stop_spin():
	is_spinning = false

func _process(delta: float) -> void:
	if not is_spinning:
		return

	spin_interval_timer += delta
	if spin_interval_timer > SPIN_INTERVAL:
		spin_interval_timer = 0
		chosen_id = randi_range(0, len(text_possible_values) - 1)
		display_label.text = text_possible_values[chosen_id]


func instant_spin():
	chosen_id = randi_range(0, len(text_possible_values) - 1)
	display_label.text = text_possible_values[chosen_id]


# Design note: All objects related to this barrel (bullet, poison cloud, ...)
# will able to contact this barrel object and call the hooks on this barrel.
# So yeah, it not really hooks. Maybe there is a more proper "hook" implementation
# but I think this is easier and faster to code.

# This is more like an interface . For each barrel, I planned to write a separate script
# for it, which should allow much more variety of effects.

## This will be alway called first. Check if can be shot.
## [Ex: Check for jamming chance / overheat / or simply not enough bullet left.]
func on_fire_attempt() -> bool:
	modification_completed.emit()
	return true

## Modify the fire rate conditionally.
## [Ex: Increased fire rate after kill / Slower fire rate if overheated.]
func on_fire_rate_check():
	return

## Run before actual fire the bullet.
## Determine how many projectiles or shooting mode will be used.
## [Ex: Add projectile amount / Burst fire / Empty magazine in 1 shot effect.]
func on_prepare_to_fire():
	return

## Check right after ammo is used.
## [Ex: Ammo leech / ammo refund if missed]
func on_ammo_consumed():
	return

## Call when magazine is empty.
## [Ex: Instant reload / Recover hp / Trigger echo damage.]
func on_clip_empty():
	return

## Cal after started reload (and start the barrel spin).
func on_reload_start():
	return

## Cal after finished reload (and stopped spinning).
func on_reload_end():
	return

func on_reload_interrupted():
	return

func on_projectile_spawn():
	return

func on_projectile_travel_tick():
	return

func on_projectile_impact():
	return

func on_projectile_destroyed():
	return

## Before deal damage to enemy.
func on_damage_calculation():
	return

## After deal damage to enemy.
func on_damage_applied():
	return

func on_enemy_killed():
	return

func on_status_effect_tick():
	return

func on_weapon_switched_to():
	return
