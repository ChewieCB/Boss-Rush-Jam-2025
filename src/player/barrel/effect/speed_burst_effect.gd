extends BaseBarrelEffect

# From 0 to 100
@export var bonus_dash_speed_perc: float = 0
@export var bonus_run_speed_perc: float = 0
@export var duration: float = 1

var dash_speed_buff_icon = preload("res://assets/sprite/buff_icon/dash_speed_up.png")
# var run_speed_buff_icon = preload("res://assets/sprite/buff_icon/run_speed_up.png")

func on_ammo_consumed():
    var dash_slide_speed_buff = StatusEffect.new()
    dash_slide_speed_buff.display_name = "Dash speed up"
    dash_slide_speed_buff.status_code = "speed_burst_barrel_dash_slide_speed"
    dash_slide_speed_buff.modified_stat = StatusEffect.PlayerStatEnum.DASH_SPEED_MODIFIER
    dash_slide_speed_buff.value = bonus_dash_speed_perc
    dash_slide_speed_buff.modify_type = StatusEffect.ModifyType.PERCENTAGE
    dash_slide_speed_buff.duration = duration
    dash_slide_speed_buff.status_icon = dash_speed_buff_icon
    GameManager.player.add_status_effect(dash_slide_speed_buff)

    var run_speed_buff = StatusEffect.new()
    run_speed_buff.display_name = "Run speed up"
    run_speed_buff.status_code = "speed_burst_barrel_run_speed"
    run_speed_buff.modified_stat = StatusEffect.PlayerStatEnum.RUN_SPEED_MODIFIER
    run_speed_buff.value = bonus_run_speed_perc
    run_speed_buff.modify_type = StatusEffect.ModifyType.PERCENTAGE
    run_speed_buff.duration = duration
    # run_speed_buff.status_icon = run_speed_buff_icon
    run_speed_buff.show_duration_ui = false
    GameManager.player.add_status_effect(run_speed_buff)