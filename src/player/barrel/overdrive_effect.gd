extends BaseBarrelEffect

@export var chance_per_ammo_spent = 1
@export var player_current_hp_explosion_dmg = 0.1

var is_active = false
var ammo_spent = 0
var explosion_sfx: AudioStream = preload("res://src/bosses/slots/assets/sfx/BOMBS/SLOT BOSS CHERRY BOMB EXPLOSION 2.mp3")


func on_barrel_remove():
	is_active = false
	ammo_spent = 0

func on_barrel_start_spin():
	is_active = false
	ammo_spent = 0
	
func on_barrel_stop_spin():
	is_active = true
	ammo_spent = 0

func on_reload_end():
	ammo_spent = 0

func on_ammo_consumed():
	super ()
	ammo_spent += 1
	if owner_barrel.owner_gun.magazine_ammo_left == 0:
		gun_explode()
		return
	else:
		# Calculate explode chance, 1% per bullet spent if not at 0 bullet yet
		var roll = randi_range(1, 100)
		if roll <= ammo_spent * chance_per_ammo_spent:
			gun_explode()


func gun_explode():
	# Create explosion
	var damage = int(GameManager.player.health_component.current_health * player_current_hp_explosion_dmg)
	var explosion_inst: ExplosionDamageArea = GameManager.object_pooling_manager.get_pooled_object(ObjectPoolingManager.PooledObjectEnum.EXPLOSION)
	explosion_inst.init(damage)
	explosion_inst.activate(GameManager.player.global_position)
	# Explosion SFX
	var rand_pitch = randf_range(0.8, 1.2)
	SoundManager.play_sound_with_pitch(explosion_sfx, rand_pitch)