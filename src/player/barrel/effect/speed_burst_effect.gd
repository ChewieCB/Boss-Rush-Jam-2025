extends BaseBarrelEffect

# From 0 to 100
@export var bonus_dash_speed_perc: float = 0
@export var bonus_run_speed_perc: float = 0
@export var duration: float = 1

func on_ammo_consumed():
    var dash_slide_speed_buff = Buff.new()
    dash_slide_speed_buff.buff_name = "speed_burst_barrel_dash_slide_speed"
    dash_slide_speed_buff.stat_name = "dash_slide_speed_modifier"
    dash_slide_speed_buff.value = bonus_dash_speed_perc
    dash_slide_speed_buff.buff_type = Buff.BuffType.PERCENTAGE
    dash_slide_speed_buff.stack_type = Buff.StackType.ADDITIVE
    dash_slide_speed_buff.duration = duration
    GameManager.player.add_buff(dash_slide_speed_buff)

    var run_speed_buff = Buff.new()
    run_speed_buff.buff_name = "speed_burst_barrel_run_speed"
    run_speed_buff.stat_name = "run_speed_modifier"
    run_speed_buff.value = bonus_run_speed_perc
    run_speed_buff.buff_type = Buff.BuffType.PERCENTAGE
    run_speed_buff.stack_type = Buff.StackType.ADDITIVE
    run_speed_buff.duration = duration
    GameManager.player.add_buff(run_speed_buff)