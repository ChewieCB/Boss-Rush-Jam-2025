extends Control
class_name StatUI

signal show
signal hide

@export_category("Components")
@export var health_component: HealthComponent
@export var luck_component: LuckComponent

@export var animate_show_hide: bool = true
@export var hide_ui_on_death: bool = true
@export var status_duration_ui_prefab: PackedScene

@onready var health_ui: Control = $PlayerHealthBarUI
@onready var luck_bar_ui: LuckBar = $PlayerLuckUI/PlayerLuckBarUI
@onready var luck_buffs_ui: Control = $PlayerLuckUI/LuckBuffsUI
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var current_ammo_label: Label = $PlayerConsumables/ConsumableUI/HBoxContainer/CurrentAmmo
@onready var magazine_size_label: Label = $PlayerConsumables/ConsumableUI/HBoxContainer/MagazineSize
@onready var status_ui_container: GridContainer = $PlayerHealthBarUI/VBoxContainer/StatusUIContainer


func _ready() -> void:
	# Await player ready
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
	GameManager.player.new_status_effect_added.connect(add_refresh_status_ui)
	GameManager.player.status_effect_removed.connect(remove_status_ui)


## Only for adding or refreshing status UI. UI usually be removed by the
## instance's timer (which hopefully synced correctly with the actual status duration)
func add_refresh_status_ui(new_status: StatusEffect):
	if not new_status.show_duration_ui:
		return
	# Check if it already exist, then refresh it
	for child in status_ui_container.get_children():
		if child.status_effect.status_code == new_status.status_code:
			child.refresh(new_status)
			return
	# Else, add new status UI item
	var ui_inst = status_duration_ui_prefab.instantiate()
	status_ui_container.add_child(ui_inst)
	ui_inst.init(new_status)

## Usually used for infinite duration status
func remove_status_ui(status_code: String):
	for child in status_ui_container.get_children():
		if child.status_effect.status_code == status_code:
			child.remove()

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


func _animate_ui_element(element: String, _show: bool = true) -> void:
	anim_player.play("%s_%s" % ["show" if _show else "hide", element])
	await anim_player.animation_finished
	return
