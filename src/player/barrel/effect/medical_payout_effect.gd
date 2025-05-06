extends BaseBarrelEffect

@export var damage_to_heal_ratio: float = 100.0

var accumulated_damage = 0

func on_damage_applied(_has_pos: bool = false, _pos: Vector3 = Vector3.ZERO):
	accumulated_damage += owner_barrel.owner_gun.modified_damage

func on_reload_start():
	GameManager.player.health_component.heal(round(accumulated_damage / damage_to_heal_ratio))
	accumulated_damage = 0
