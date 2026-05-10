extends BaseBarrelEffect

func on_projectile_spawn(projectile: BaseBullet):
	projectile.life_time += 10
	projectile.switch_to_slowmo_bullet_trail()