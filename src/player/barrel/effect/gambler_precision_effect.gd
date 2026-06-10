extends BaseBarrelEffect

# TODO: Possible rework into roll a dice from 1 to 6 and do something with crit dmg with it

## In %, so 50 = 50%
@export var crit_chance: float
## In %, so 50 = 50%
@export var jam_chance_if_missed: float
@export var jam_anim_delay: float = 1.0
# Luck gain values
@export var luck_gain_on_crit: float = 4
#
@export var luck_trigger_consecutive_shots: int = 4
@export var luck_gain_consecutive_shot: float = 25.0

var hit_count = 0
var projectile_count = 0
var consecutive_hit_count: int = 0

func on_prepare_to_fire():
	super ()
	hit_count = 0
	projectile_count = 0


func on_before_damage_applied(enemy: CharacterBody3D, projectile: BaseBullet):
	super (enemy, projectile)
	# Minor luck gain on crit
	if projectile.is_crit:
		# Mark the luck trigger as discovered if we haven't triggered it before
		LuckHandler.check_discover_luck_trigger(LuckTriggerInfo.LuckTriggerIdEnum.GAMBLERS_PRECISION__LUCKY_SHOT)
		LuckHandler.increase_luck(luck_gain_on_crit, "+4 Lucky shot!")

func on_projectile_destroyed(_projectile: BaseBullet, _hit_boss: bool):
	super (_projectile, _hit_boss)
	projectile_count += 1
	
	# We only check for missed after all projectiles destroyed
	if projectile_count == owner_barrel.owner_gun.modified_projectile_amount:
		if hit_count <= 0: # Only trigger the jam if ALL projectiles have missed
			consecutive_hit_count = 0
			var roll = randi_range(1, 100)
			if roll <= jam_chance_if_missed:
				owner_barrel.owner_gun.jam_gun(jam_anim_delay)
		
		consecutive_hit_count += 1
		if consecutive_hit_count >= luck_trigger_consecutive_shots:
			# Mark the luck trigger as discovered if we haven't triggered it before
			LuckHandler.check_discover_luck_trigger(LuckTriggerInfo.LuckTriggerIdEnum.GAMBLERS_PRECISION__LET_IT_RIDE)
			LuckHandler.increase_luck(luck_gain_consecutive_shot, "+25 Let it ride!")
			consecutive_hit_count = 0


func on_projectile_spawn(projectile: BaseBullet):
	projectile.crit_chance += (crit_chance / 100.0)


func on_damage_applied(_damage: float, _has_pos: bool = false, _pos: Vector3 = Vector3.ZERO):
	super (_damage, _has_pos, _pos)
	hit_count += 1
