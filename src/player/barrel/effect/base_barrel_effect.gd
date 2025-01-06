extends Node
class_name BaseBarrelEffect

@export_multiline var display_text: String

var owner_barrel: SpinBarrel
## This variable is to prevent a single shot trigger the effect multiple times.
## Usually common case with shotgun with or gun with lots of projectile count.
## For example, a shotgun with 20 projectile counts may trigger refund bullet 
## effect up to 20 times, while only cost 1 ammo, in a single shot.
var triggered_this_shot = false

## This will be alway called first. Check if can be shot.
## [Ex: Check for jamming chance / overheat / or simply not enough bullet left.]
func on_fire_attempt() -> bool:
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
