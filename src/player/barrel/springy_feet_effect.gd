extends BaseBarrelEffect

var active = false

# func _process(_delta: float) -> void:
# 	if not active:
# 		return
# 	if not GameManager.player.is_on_floor():
# 		GameManager.player.current_gun.shoot(GameManager.player.aim_ray)

func on_barrel_install():
	active = true

func on_barrel_stop_spin():
	active = true

func on_barrel_remove():
	active = false

func on_barrel_start_spin():
	active = false

func on_fire_attempt() -> bool:
	return not GameManager.player.is_on_floor()
