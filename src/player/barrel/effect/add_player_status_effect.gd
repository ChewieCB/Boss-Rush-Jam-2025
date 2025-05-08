extends BaseBarrelEffect


@export var display_name: String
@export var status_code: String
@export var modified_stat: StatusEffect.PlayerStatEnum
@export var modify_type: StatusEffect.ModifyType
@export var value: float
@export var is_infinite_duration = false
@export var duration: float = 0
@export var is_bad_effect: bool
@export var status_icon: Texture2D
@export var show_duration_ui: bool = true

func create_status_effect() -> StatusEffect:
	var status = StatusEffect.new()
	status.display_name = display_name
	status.status_code = status_code
	status.modified_stat = modified_stat
	status.value = value
	status.modify_type = modify_type
	if is_infinite_duration:
		status.duration = StatusEffect.INFINITE_DURATION
	else:
		status.duration = duration
	status.is_bad_effect = true
	status.status_icon = status_icon
	return status


func create_effect():
	var status = create_status_effect()
	GameManager.player.add_status_effect(status)

func remove_effect():
	GameManager.player.remove_status_effect_by_name(status_code)


func on_barrel_remove():
	remove_effect()

func on_barrel_start_spin():
	remove_effect()

func on_barrel_stop_spin():
	create_effect()
