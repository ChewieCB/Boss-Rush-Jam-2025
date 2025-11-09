extends BaseBarrelEffect

enum TriggerActionEnum {
	NONE,
	DASH,
	RELOAD,
	DAMAGE_APPLIED
}

@export var trigger_action: TriggerActionEnum
@export var prefab: PackedScene

## Prevent multishot weapon spawn prefab multiple times in 1 shot
@export var limit_once_per_shot = false
## Can trigger once every this seconds
@export var min_time_passed: float = 0
## 0 to 100
@export var chance_perc: float = 100

var triggered = false
var timer: Timer

func _ready() -> void:
	if timer == null:
		timer = Timer.new()
		timer.wait_time = 0.1
		timer.one_shot = true
		add_child(timer)


func check_if_can_trigger() -> bool:
	if limit_once_per_shot and triggered:
		return false
	if min_time_passed > 0 and not timer.is_stopped():
		return false
	var roll = randf_range(1, 100)
	if roll > chance_perc:
		return false

	# Can trigger, now set it triggered
	triggered = true
	if min_time_passed > 0:
		timer.start(min_time_passed)
	return true

func on_prepare_to_fire():
	super ()
	triggered = false


func on_damage_applied(_damage: float, _has_pos: bool = false, _pos: Vector3 = Vector3.ZERO):
	super (_damage, _has_pos, _pos)
	if trigger_action == TriggerActionEnum.DAMAGE_APPLIED:
		if not check_if_can_trigger():
			return
		if _has_pos:
			var inst = prefab.instantiate()
			GameManager.player.get_parent().add_child(inst)
			inst.global_position = _pos

func on_dash_movement():
	super ()
	if trigger_action == TriggerActionEnum.DASH:
		if not check_if_can_trigger():
			print("FALLLLLL")
			return
		var inst = prefab.instantiate()
		GameManager.player.get_parent().add_child(inst)
		inst.global_position = GameManager.player.global_position


func on_reload_start():
	super ()
	if trigger_action == TriggerActionEnum.RELOAD:
		if not check_if_can_trigger():
			return
		var inst = prefab.instantiate()
		GameManager.player.get_parent().add_child(inst)
		inst.global_position = GameManager.player.global_position
