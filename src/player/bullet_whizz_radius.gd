extends Area3D

@export var bullet_whizz_sfx: AudioStream

const MIN_LIFE_TIME = 0.1 # Prevent bullet whizz sound from bullet that we shoot

func _on_area_entered(area: Area3D) -> void:
	if area.get_parent() and area.get_parent() is GunProjectile:
		var proj: GunProjectile = area.get_parent() as GunProjectile
		if proj.life_time > MIN_LIFE_TIME:
			SoundManager.play_sound_3d(bullet_whizz_sfx, proj.global_position, randf_range(0.7, 1.3), "SFX")
	if area.get_parent() and area.get_parent() is BaseBossProjectile:
		var proj: BaseBossProjectile = area.get_parent() as BaseBossProjectile
		SoundManager.play_sound_3d(bullet_whizz_sfx, proj.global_position, randf_range(0.7, 1.3), "SFX")
