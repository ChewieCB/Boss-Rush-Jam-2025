extends BaseBarrelEffect

# From 0 to 100
@export var bonus_dash_speed_perc: float = 0
@export var bonus_run_speed_perc:float = 0
@export var duration: float = 1

var timer: Timer

func _ready():
    timer = Timer.new()
    timer.wait_time = 1
    timer.one_shot = true
    add_child(timer)
    timer.timeout.connect(stop_speed_bonus)


func on_ammo_consumed():
    timer.start()
    var new_dash_slide_speed_modifier = 1 + (bonus_dash_speed_perc / 100.0)
    GameManager.player.dash_slide_speed_modifier = new_dash_slide_speed_modifier
    var new_run_speed_modifier = 1 + (bonus_run_speed_perc / 100.0)
    GameManager.player.run_speed_modifier = new_run_speed_modifier

func stop_speed_bonus():
    GameManager.player.dash_slide_speed_modifier = 1.0
    GameManager.player.run_speed_modifier = 1.0