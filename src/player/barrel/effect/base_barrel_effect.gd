extends Node
class_name BaseBarrelEffect

# NOTE: Do not change the enum order
enum AttributeNameEnum {
	NONE,
	DAMAGE,
	PROJECTILE_AMOUNT,
	PROJECTILE_SPEED,
	FIRERATE,
	MAGAZINE_SIZE,
	IS_HITSCAN,
	SPREAD_ANGLE,
	RELOAD_TIME,
	RICOCHET_COUNT,
	HOMING_STRENGTH,
	RECOIL,
	SCREENSHAKE,
	SPREAD_HORIZONTAL_BIAS,
	LIFETIME
}

@export_multiline var display_text_title: String
@export_multiline var display_text_tag: String
@export var positive_desc: Array[String]
@export var negative_desc: Array[String]
@export var icon_id: int = -1
@export var is_archetype: bool = false
@export var luck_triggers: Array[LuckTriggerInfo.LuckTriggerIdEnum]

var owner_barrel: SpinBarrel
## This variable is to prevent a single shot trigger the effect multiple times.
## Usually common case with shotgun with or gun with lots of projectile count.
## For example, a shotgun with 20 projectile counts may trigger refund bullet 
## effect up to 20 times, while only cost 1 ammo, in a single shot.
var triggered_this_shot = false


func get_icon_path() -> String:
	return "res://src/player/gun/assets/sprite/effect_icons/%s" % icon_id


func calculate_new_value(old_value: float, modify_value: float, is_perc: bool, rounding: bool):
	var new_value = 0
	if is_perc:
		new_value = old_value * (1 + (modify_value / 100.0))
	else:
		new_value = old_value + modify_value

	if rounding:
		new_value = round(new_value)
	return new_value


func on_barrel_install():
	return

func on_barrel_remove():
	return

func on_barrel_start_spin():
	return

func on_barrel_stop_spin():
	return

## Call when an effect is first applied
func on_effect_set():
	return

## Call when player start to hold or click LMB (or shoot button)
func on_trigger_pulled():
	return

## Call when player released LMB (or shoot button)
func on_trigger_released():
	return

## Check if can be shot. Return bool.
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

## Call after started reload
func on_reload_start():
	return

## Call after finished reload
func on_reload_end():
	return

func on_reload_interrupted():
	return

## When bullet spawned / actual shooting happened
func on_projectile_spawn(_projectile: BaseBullet):
	return

func on_projectile_travel_tick():
	return

func on_projectile_impact(_projectile: BaseBullet, _has_pos: bool = false, _pos: Vector3 = Vector3.ZERO):
	return

func on_projectile_destroyed(_hit_boss: bool):
	return

## Before bullet go out of barrel. Not take into account bullet effect yet.
func on_gun_damage_calculation():
	return

## When bullet hit enemy but JUST before applied damage (but after normal damage calculation).
## You can modify bullet damage which take into account bonus of each bullet here.
func on_before_damage_applied(_enemy: CharacterBody3D, _projectile: BaseBullet):
	return

## After deal damage to enemy.
func on_damage_applied(_damage: float, _has_pos: bool = false, _pos: Vector3 = Vector3.ZERO):
	return

func on_enemy_killed():
	return

func on_status_effect_tick():
	return

func on_weapon_switched_to():
	return

func on_dash_movement():
	return

func on_player_damaged():
	return
