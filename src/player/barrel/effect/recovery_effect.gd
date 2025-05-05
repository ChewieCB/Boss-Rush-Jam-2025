extends BaseBarrelEffect

@export var heal_barrier_prefab: PackedScene
@export var heal_amount: int = 1
@export var heal_interval: float = 3

var timer: Timer
var heal_barrier_inst = null

var recovery_status_icon = preload("res://assets/sprite/buff_icon/health_normal.png")

func _ready():
	if timer == null:
		timer = Timer.new()
		timer.wait_time = heal_interval
		timer.one_shot = false
		add_child(timer)
		timer.timeout.connect(heal)

func on_reload_start():
	# Remove the effect
	timer.stop()
	if heal_barrier_inst != null:
		heal_barrier_inst.queue_free()
		GameManager.player.remove_status_effect_by_name("recovery_effect_regenerate")


func on_reload_end():
	# Create the effect
	timer.start()
	if heal_barrier_inst == null:
		heal_barrier_inst = heal_barrier_prefab.instantiate()
		GameManager.player.add_child(heal_barrier_inst)
		var status_effect = create_recovery_status_effect()
		GameManager.player.add_status_effect(status_effect)


func on_barrel_remove():
	on_reload_start()

func on_barrel_spin():
	on_reload_start()


func heal():
	GameManager.player.health_component.heal(heal_amount)

func create_recovery_status_effect() -> StatusEffect:
	# Just to display the status UI, dont actually do anything
	var recovery_status_effect = StatusEffect.new()
	recovery_status_effect.display_name = "Regenerate"
	recovery_status_effect.status_code = "recovery_effect_regenerate"
	recovery_status_effect.modified_stat_name = ""
	recovery_status_effect.value = heal_amount
	recovery_status_effect.modify_type = StatusEffect.StatusEffectModifyType.FLAT
	recovery_status_effect.duration = StatusEffect.INFINITE_DURATION
	recovery_status_effect.is_bad_effect = false
	recovery_status_effect.status_icon = recovery_status_icon
	return recovery_status_effect