extends BaseBarrelEffect

@export var heal_barrier_prefab: PackedScene
@export var heal_amount: int = 1
@export var heal_interval: float = 3

var timer: Timer
var heal_barrier_inst = null

func _ready():
	if timer == null:
		timer = Timer.new()
		timer.wait_time = heal_interval
		timer.one_shot = false
		add_child(timer)
		timer.timeout.connect(heal)

func on_reload_start():
	timer.stop()
	if heal_barrier_inst != null:
		heal_barrier_inst.queue_free()


func on_reload_end():
	timer.start()
	if heal_barrier_inst == null:
		heal_barrier_inst = heal_barrier_prefab.instantiate()
		GameManager.player.add_child(heal_barrier_inst)


func on_barrel_remove():
	on_reload_start()

func heal():
	GameManager.player.health_component.heal(heal_amount)