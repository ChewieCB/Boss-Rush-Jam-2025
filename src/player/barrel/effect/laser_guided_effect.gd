extends BaseBarrelEffect


func on_projectile_spawn(projectile: BaseBullet):
	projectile.can_be_aim_guided = true
