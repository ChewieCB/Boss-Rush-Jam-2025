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

@export var health_ui: Control
@export var luck_bar_ui: Control
@export var luck_buffs_ui: Control
@export var anim_player: AnimationPlayer
@export var status_ui_container: Container

@export var spin_ability_ui: TextureProgressBar
@export var fill_time: float = 0.1
@export var roll_left_label: Label
var out_of_reroll = false

@export var radial_ui_center_node: Control
@export var currency_ui: Control


func _ready() -> void:
	# Await player ready 
	if get_owner():
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
	# FIXME - remove conditional after debugging?
	if GameManager.player:
		GameManager.player.new_status_effect_added.connect(add_refresh_status_ui)
		GameManager.player.status_effect_removed.connect(remove_status_ui)
	
	#hide_all_ui()
	
	# Spin abiltiy UI
	_update_reroll_max(int(GameManager.reroll_cost * GameManager.get_risk_spin_cost_mult()))
	GameManager.currency_changed.connect(_on_currency_changed)
	GameManager.reroll_cost_changed.connect(_update_reroll_max)
	GameManager.free_rerolls.connect(_update_reroll_max.bind(spin_ability_ui.max_value))
	#_update_roll_left_label()


func _on_spin_ability_progress_changed(value: float) -> void:
	var progress_mat: ShaderMaterial = spin_ability_ui.material
	progress_mat.set_shader_parameter("progress", value)
	
	if out_of_reroll:
		spin_ability_ui.tint_progress = Color.GRAY
		spin_ability_ui.material.set_shader_parameter("fill_colour", Color.GRAY)
		#progress_label.text = "Limited"
		#anim_player.stop()
		return
		
	if value >= spin_ability_ui.max_value:
		spin_ability_ui.tint_progress = Color.GOLD
		spin_ability_ui.material.set_shader_parameter("fill_colour", Color.GOLD)
		#progress_label.modulate = Color.GOLD
		#anim_player.play("spin")
	else:
		spin_ability_ui.tint_progress = Color.LIGHT_GREEN
		spin_ability_ui.material.set_shader_parameter("fill_colour", Color.LIGHT_GREEN)
		#progress_label.modulate = Color.GRAY
		#anim_player.stop()


func _on_currency_changed(new_value: int) -> void:
	var fill_time: float = 0.5
	var progress_tween: Tween = get_tree().create_tween()
	progress_tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	progress_tween.tween_property(spin_ability_ui, "value", new_value, fill_time).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)


func _update_reroll_max(new_max: int) -> void:
	spin_ability_ui.max_value = float(new_max)
	spin_ability_ui.material.set_shader_parameter("max_value", new_max)
	
	var new_value: int
	if not GameManager.is_free_reroll:
		new_value = min(GameManager.player_currency, spin_ability_ui.max_value)
		#progress_label.text = "%s" % new_max
	else:
		new_value = int(spin_ability_ui.max_value)
		#progress_label.text = "Free"
	var progress_tween: Tween = get_tree().create_tween()
	progress_tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	progress_tween.tween_property(spin_ability_ui, "value", 0, fill_time * 4).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	progress_tween.chain().tween_property(spin_ability_ui, "value", new_value, fill_time * 4).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	#_update_roll_left_label()


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
