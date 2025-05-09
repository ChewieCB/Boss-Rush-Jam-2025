extends BaseBarrelEffect


func _process(_delta: float) -> void:
	if GameManager.player.is_dashing:
		GameManager.player.current_gun.shoot(GameManager.player.aim_ray)


func on_fire_attempt() -> bool:
	return GameManager.player.is_dashing
