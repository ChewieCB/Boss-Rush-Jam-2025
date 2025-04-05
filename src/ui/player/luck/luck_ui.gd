extends MarginContainer
class_name LuckBar

signal show
signal hide

@export_category("Components")
@export var luck_component: LuckComponent


@export var show_on_ready: bool = true
@export var animate_show_hide: bool = true
@export var hide_ui_on_death: bool = false

@onready var timer: Timer = $MarginContainer/LuckBar/Timer
@onready var luck_bar: TextureProgressBar = $MarginContainer/LuckBar
@onready var luck_gain_bar: TextureProgressBar = $MarginContainer/LuckBar/LuckGainBar
#@onready var anim_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	await get_owner().ready
	if luck_component:
		init_luck_ui(luck_component.current_luck, luck_component.max_luck)
		luck_component.luck_changed.connect(_on_luck_changed)
		luck_component.luck_maxed.connect(_on_luck_maxed)
	#if show_on_ready:
		#show_ui()


func init_luck_ui(_luck, _max_luck) -> void:
	luck_bar.max_value = _max_luck
	luck_bar.value = _luck
	luck_gain_bar.max_value = _max_luck
	luck_gain_bar.value = _luck


#func show_ui() -> void:
	#if animate_show_hide:
		#anim_player.play("show")
	#else:
		#anim_player.play("visible")
	#show.emit()
#
#
#func hide_ui() -> void:
	#if animate_show_hide:
		#anim_player.play("hide")
	#else:
		#anim_player.play("invisible")
	#hide.emit()


func _on_luck_changed(new_luck: float, prev_luck: float) -> void:	
	if new_luck < prev_luck:
		luck_bar.value = new_luck
	else:
		luck_gain_bar.value = new_luck
	
	timer.start()


func _on_luck_maxed() -> void:
	pass


func _on_timer_timeout():
	luck_bar.value = luck_component.current_luck
	luck_gain_bar.value = luck_component.current_luck
