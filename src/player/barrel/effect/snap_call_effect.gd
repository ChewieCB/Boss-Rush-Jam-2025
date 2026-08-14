extends BaseBarrelEffect

## When projectile speed less than this, it deal less dmg
## otherwise, deal more dmg
@export var speed_threshold: float = 50
## How much dmg projectile is modified depend on difference between this 
## and threshold, per godot's unit
@export var dmg_modify_perc_per_unit: float = 1

@export var player_speed_bonus_mult = 4
@export var player_dash_mult = 2

const HIGH_SPEED_THRESHOLD = 100


func on_projectile_spawn(projectile: BaseBullet):
	# Add player current speed to projectile
	var bonus_speed = GameManager.player.vel_horizontal.length() * player_speed_bonus_mult
	if GameManager.player.is_dashing:
		bonus_speed *= player_dash_mult
	projectile.projectile_speed += bonus_speed


func on_before_damage_applied(_enemy: CharacterBody3D, projectile: BaseBullet):
	# If hitscan, just ignore it
	if projectile.is_hitscan:
		# projectile.damage = projectile.damage * dmg_modify_for_hitscan
		return
	var dist_diff = abs(speed_threshold - projectile.projectile_speed)
	var perc_changed = dist_diff * dmg_modify_perc_per_unit
	if projectile.projectile_speed < speed_threshold:
		perc_changed = - perc_changed
	projectile.damage += round(projectile.damage * (perc_changed / 100))