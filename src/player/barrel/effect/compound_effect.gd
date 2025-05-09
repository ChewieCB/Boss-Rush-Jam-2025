extends BaseBarrelEffect

@export var is_archetype: bool = false
@export var archetype_reload_sfx: Array[AudioStream]
@export var archetype_shot_sfx: Array[AudioStream]

var child_effects: Array[BaseBarrelEffect]

# This is a special effect, that combined the effect from other script.
# Does not work on its own, need to add other effects as children.

func _ready() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame

	for child in get_children():
		var barrel = child as BaseBarrelEffect
		barrel.owner_barrel = owner_barrel
		child_effects.append(barrel)

func on_barrel_install():
	for child in child_effects:
		child.on_barrel_install()

func on_barrel_remove():
	for child in child_effects:
		child.on_barrel_remove()

func on_barrel_start_spin():
	for child in child_effects:
		child.on_barrel_start_spin()

func on_barrel_stop_spin():
	for child in child_effects:
		child.on_barrel_stop_spin()

func on_effect_set():
	for child in child_effects:
		child.on_effect_set()

func on_fire_attempt() -> bool:
	var res = true
	for child in child_effects:
		res = res and child.on_fire_attempt()
	return res

func on_fire_rate_check():
	for child in child_effects:
		child.on_fire_rate_check()

func on_prepare_to_fire():
	for child in child_effects:
		child.on_prepare_to_fire()

func on_ammo_consumed():
	if is_archetype:
		SoundManager.play_sound_with_pitch(archetype_shot_sfx.pick_random(), randf_range(0.85, 1.15), "Gun")
	for child in child_effects:
		child.on_ammo_consumed()

func on_clip_empty():
	for child in child_effects:
		child.on_clip_empty()

func on_reload_start():
	for child in child_effects:
		child.on_reload_start()

func on_reload_end():
	if is_archetype:
		SoundManager.play_sound(archetype_reload_sfx.pick_random(), "Gun")
	for child in child_effects:
		child.on_reload_end()


func on_reload_interrupted():
	for child in child_effects:
		child.on_reload_interrupted()

func on_projectile_spawn():
	for child in child_effects:
		child.on_projectile_spawn()

func on_projectile_travel_tick():
	for child in child_effects:
		child.on_projectile_travel_tick()

func on_projectile_impact(_has_pos: bool = false, _pos: Vector3 = Vector3.ZERO):
	for child in child_effects:
		child.on_projectile_impact(_has_pos, _pos)

func on_projectile_destroyed():
	for child in child_effects:
		child.on_projectile_destroyed()

func on_damage_calculation():
	for child in child_effects:
		child.on_damage_calculation()

func on_before_damage_applied(_enemy: CharacterBody3D, _projectile: BaseProjectile):
	for child in child_effects:
		child.on_before_damage_applied(_enemy, _projectile)

func on_damage_applied(_has_pos: bool = false, _pos: Vector3 = Vector3.ZERO):
	for child in child_effects:
		child.on_damage_applied(_has_pos, _pos)

func on_enemy_killed():
	for child in child_effects:
		child.on_enemy_killed()

func on_status_effect_tick():
	for child in child_effects:
		child.on_status_effect_tick()

func on_weapon_switched_to():
	for child in child_effects:
		child.on_weapon_switched_to()

func on_dash_movement():
	for child in child_effects:
		child.on_dash_movement()
