extends BaseBarrelEffect

@export var retaliate_time: float = 1
@export var damage_modify_perc: float = 100

var timer: Timer
var status_icon = preload("res://assets/sprite/status_icon/reactive_shot.png")

func _ready():
	if timer == null:
		timer = Timer.new()
		timer.wait_time = retaliate_time
		timer.one_shot = true
		add_child(timer)

func on_gun_damage_calculation():
	super ()
	if not timer.is_stopped():
		owner_barrel.owner_gun.modified_damage = round(owner_barrel.owner_gun.modified_damage * (1 + (damage_modify_perc / 100.0)))

func on_player_damaged():
	super ()
	timer.start(retaliate_time)
	var status = create_reactive_shot_effect()
	GameManager.player.add_status_effect(status)

func remove_effect():
	timer.stop()
	GameManager.player.remove_status_effect_by_name("reactive_shot_damage_increased")


func on_barrel_remove():
	remove_effect()

func on_barrel_start_spin():
	remove_effect()


func create_reactive_shot_effect() -> StatusEffect:
	# Just to display the status UI, not actually do anything
	var reactive_shot_effect = StatusEffect.new()
	reactive_shot_effect.display_name = "Damage increased"
	reactive_shot_effect.status_code = "reactive_shot_damage_increased"
	reactive_shot_effect.modified_stat = StatusEffect.PlayerStatEnum.NONE
	reactive_shot_effect.value = 0
	reactive_shot_effect.modify_type = StatusEffect.ModifyType.FLAT
	reactive_shot_effect.duration = retaliate_time
	reactive_shot_effect.is_bad_effect = false
	reactive_shot_effect.status_icon = status_icon
	return reactive_shot_effect