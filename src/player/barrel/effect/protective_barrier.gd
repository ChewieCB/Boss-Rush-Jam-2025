extends BaseBarrelEffect

@export var shield_barrier_prefab: PackedScene
@export var damage_reduction_perc: float

var shield_barrier_inst = null

func on_reload_start():
	GameManager.player.health_component.modified_resistance = 1
	if shield_barrier_inst != null:
		shield_barrier_inst.queue_free()


func on_reload_end():
	GameManager.player.health_component.modified_resistance = damage_reduction_perc / 100.0
	if shield_barrier_inst == null:
		shield_barrier_inst = shield_barrier_prefab.instantiate()
		GameManager.player.add_child(shield_barrier_inst)

func on_barrel_remove():
	on_reload_start()
