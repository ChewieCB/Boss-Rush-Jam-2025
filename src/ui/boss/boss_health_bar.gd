extends HealthBar
class_name BossHealthBar

@export var boss_name: String = "":
	set(value):
		boss_name = value
		if name_label:
			name_label.text = boss_name

@onready var name_label: Label = $VBoxContainer/MarginContainer2/HBoxContainer/MarginContainer2/Label
@onready var anim_player: AnimationPlayer = $AnimationPlayer

@onready var status_container: Container = $VBoxContainer/StatusContainer

@onready var phase_icon_container: HBoxContainer = $VBoxContainer/HBoxContainer/PhaseIcons/HBoxContainer
@export var phase_icon_prefab: PackedScene

@export_category("Health Phases")
@export var phase_health_arr: Array[int]
var ui_current_health: int


func _ready() -> void:
	super()
	name_label.text = boss_name
	if health_component:
		#init_health_ui(health_component.current_health)
		health_component.health_changed.connect(_on_health_changed)
		health_component.max_health_changed.connect(_on_max_health_changed)
	
	await get_tree().process_frame
	await get_tree().process_frame
	GameManager.setting_ui.setting_changed.connect(check_after_setting_changed)
	check_after_setting_changed()


func _on_timer_timeout():
	var tween: Tween = get_tree().create_tween()
	tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tween.tween_property(damage_bar, "value", health_bar.value, 0.4)


func _on_health_changed(new_health: float, prev_health: float) -> void:
	var diff = prev_health - new_health
	ui_current_health -= diff
	
	if new_health <= 0:
		ui_current_health = 0
	
	anim_health_ui_scale(1.05)
	
	var tween: Tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tween.tween_property(health_bar, "value", ui_current_health, 0.4)
	health_label.text = "%s/%s" % [ui_current_health + diff, health_bar.max_value]
	
	timer.start()


func init_boss_health_ui(phase_count: int = phase_health_arr.size()) -> void:
	var new_health: int = phase_health_arr.pop_front()
	if new_health:
		init_health_bar(new_health)
		clear_phase_markers()
		init_phase_markers(phase_count)

func next_health_bar() -> void:
	var new_health: int = phase_health_arr.pop_front()
	if new_health:
		init_health_bar(new_health)

func init_health_bar(max_health: int) -> void:
	ui_current_health = max_health
	health_bar.max_value = max_health
	damage_bar.max_value = max_health
	health_label.text = "%s/%s" % [max_health, max_health]
	
	anim_health_ui_scale(1.25)
	
	var tween: Tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tween.tween_property(health_bar, "value", max_health, 0.4)
	tween.tween_property(damage_bar, "value", max_health, 0.4)


func init_phase_markers(count: int) -> void:
	for i in range(count):
		var phase_icon = phase_icon_prefab.instantiate()
		phase_icon_container.add_child(phase_icon)

func clear_phase_markers() -> void:
	for child in phase_icon_container.get_children():
		child.queue_free()

func empty_phase_marker(idx: int) -> void:
	var icon = phase_icon_container.get_child(idx)
	icon.get_child(1).modulate = Color.DIM_GRAY
	# TODO - add some juice and particle effects when a phase is done 
	UIUtils.anim_ui_elem_scale(icon, 1.2)


func check_after_setting_changed():
	visible = not GameManager.hide_ui


func anim_health_ui_scale(amount: float = 1.1, speed_scale: float = 1.0) -> void:
	UIUtils.anim_ui_elem_scale(health_bar, amount, speed_scale)


func show_ui() -> void:
	anim_player.play("show")


func hide_ui() -> void:
	anim_player.play("hide")


func change_status_label_visibility(status: BossCore.BossStatusEffect, set_to_visible: bool):
	var node_name: String = BossCore.BossStatusEffect.keys()[status].to_pascal_case()
	var found_node: Control = status_container.get_node(node_name)
	if found_node:
		found_node.visible = set_to_visible
