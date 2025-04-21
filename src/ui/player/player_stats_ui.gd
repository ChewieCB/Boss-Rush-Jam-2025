extends Control
class_name PlayerUI

signal show
signal hide

@export_category("Components")
@export var health_component: HealthComponent
@export var luck_component: LuckComponent

@onready var health_ui: Control = $PlayerStatsUI/VBoxContainer/PlayerHealthBarUI
@onready var luck_bar_ui: Control = $PlayerStatsUI/VBoxContainer/PlayerLuckUI/PlayerLuckBarUI
@onready var luck_buffs_ui: Control = $PlayerStatsUI/VBoxContainer/PlayerLuckUI/LuckBuffsUI

@export var animate_show_hide: bool = true
@export var hide_ui_on_death: bool = true

@onready var anim_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	await get_owner().ready
	health_ui.health_component = health_component
	luck_bar_ui.luck_component = luck_component
	if health_component:
		health_ui.init_health_ui(health_component.current_health)
		health_component.health_changed.connect(health_ui._on_health_changed)
	if luck_component:
		luck_bar_ui.init_luck_ui(luck_component.current_luck, luck_component.max_luck)
		luck_component.luck_changed.connect(luck_bar_ui._on_luck_changed)
		luck_component.luck_maxed.connect(luck_bar_ui._on_luck_maxed)
	#if show_on_ready:
		#show_ui()


func show_health_ui() -> void:
	_animate_ui_element("health")


func hide_health_ui() -> void:
	_animate_ui_element("health", false)


func show_luck_ui() -> void:
	_animate_ui_element("luck")


func hide_luck_ui() -> void:
	_animate_ui_element("luck", false)


func show_non_luck_ui() -> void:
	_animate_ui_element("non_luck")


func hide_non_luck_ui() -> void:
	_animate_ui_element("non_luck", false)


func show_all_ui() -> void:
	_animate_ui_element("all")


func hide_all_ui() -> void:
	_animate_ui_element("all", false)


func _animate_ui_element(element: String, show: bool = true) -> void:
	anim_player.play("%s_%s" % ["show" if show else "hide", element])
	await anim_player.animation_finished
	return
