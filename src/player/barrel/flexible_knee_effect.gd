extends BaseBarrelEffect

@export var crouch_iframe_duration = 0.2
@export var crouch_iframe_cd = 1

var active = false
var dash_iframe_icon = preload("res://assets/sprite/status_icon/invincible.png")
var timer: Timer

func _ready():
	await owner.ready
	if timer == null:
		timer = Timer.new()
		timer.wait_time = crouch_iframe_cd
		timer.one_shot = true
		add_child(timer)

	await get_tree().process_frame
	await get_tree().process_frame
	GameManager.player.movement_crouched.connect(add_iframe_on_crouch)


# func _process(_delta: float) -> void:
# 	if not active:
# 		return
# 	if GameManager.player.is_crouching:
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
	return GameManager.player.is_crouching


func add_iframe_on_crouch():
	if not timer.is_stopped() or not active:
		return
	# if not GameManager.player.is_crouching:
	# 	return
	timer.start()
	var iframe_dash_buff = StatusEffect.new()
	iframe_dash_buff.display_name = "Dodging"
	iframe_dash_buff.status_code = "flexible_knee_iframe_on_crouch"
	iframe_dash_buff.modified_stat = StatusEffect.PlayerStatEnum.IS_INVINVIBLE
	iframe_dash_buff.value = 1 # Doesnt matter
	iframe_dash_buff.modify_type = StatusEffect.ModifyType.BOOL
	iframe_dash_buff.duration = crouch_iframe_duration
	iframe_dash_buff.status_icon = dash_iframe_icon
	GameManager.player.add_status_effect(iframe_dash_buff)
