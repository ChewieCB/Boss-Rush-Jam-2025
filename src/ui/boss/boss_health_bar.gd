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

@export var total_health: float
@export var sub_bar_count: int = 1
@export var sub_health_bars_container: HBoxContainer
@export var sub_health_bar_prefab: PackedScene

# TODO - save the health bar margin container as a separate scene, add a hbox container and instance a health bar per-phase as needed
#
# the health pool should be split across the health bars as determined by per-phase health
#`
# keep track of the current phase health bar and decrement/increment that
#
# once a health bar is depleted, it can't be re-filled by healing the boss, so the max health is reduced after each phase

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


func init_boss_health_ui(max_health: int, sub_health_bars: int) -> void:
	total_health = max_health
	sub_bar_count = sub_health_bars
	for i in range(sub_health_bars):
		add_sub_health_bar(max_health / sub_bar_count)


func add_sub_health_bar(_health: int) -> BossSubHealthBar:
	var _bar = sub_health_bar_prefab.instantiate()
	sub_health_bars_container.add_child(_bar)
	#sub_health_bars_container.move_child(_bar, 0)
	_bar.init_bars(_health)
	
	
	return _bar


func clear_sub_health_bars() -> void:
	for child in sub_health_bars_container.get_children():
		child.queue_free()
		sub_health_bars_container.remove_child(child)
		


func _on_health_changed(new_health: float, prev_health: float) -> void:
	var diff = prev_health - new_health
	var overspill: float = 0.0
	
	var health_bars = sub_health_bars_container.get_children()
	health_bars.reverse()
	
	if new_health < prev_health:
		for child in health_bars:
			if child == null:
				continue
			child.label.text = "%s/%s" % [child.health_bar.value, child.health_bar.max_value]
			# If we have health left on the bar
			if child.health_bar.value > 0:
				# Figure out how much health we can take
				if diff > child.health_bar.value:
					# Store the extra damage this bar can't remove
					overspill = diff - child.health_bar.value
					# Zero the bar
					child.health_bar.value = 0
					diff = 0.0
					# Move on to the next bar
					continue
				else:
					# Decrease the bar value
					child.health_bar.value -= diff
					diff = 0.0
					# If we have overspill, also apply this
					if overspill < child.health_bar.value:
						child.health_bar.value -= overspill
						overspill = 0.0
						continue
					else:
						overspill -= child.health_bar.value
						child.health_bar.value = 0.0
						continue
			else:
				child.damage_bar.value = child.health_bar.value
		timer.start()
	else:
		for child in health_bars:
			if child == null:
				continue
			if not child is BossSubHealthBar:
				continue
			child.label.text = "%s/%s" % [child.health_bar.value, child.health_bar.max_value]
			# If we have health left on the bar, update it
			if child.health_bar.value > 0:
				if child.health_bar.value >= int(new_health):
					continue
				child.damage_bar.value = int(new_health)
				await get_tree().create_timer(0.3).timeout
				if child == null:
					continue
				if "health_bar" in child:
					if child.health_bar == null:
						continue
					var tween: Tween = get_tree().create_tween()
					tween.tween_property(child.health_bar, "value", int(new_health), 0.4).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
					await tween.finished
					child.health_bar.value = int(new_health)
			else:
				child.damage_bar.value = child.health_bar.value


func _on_timer_timeout():
	var health_bars = sub_health_bars_container.get_children()
	health_bars.reverse()
	
	for child in health_bars:
		# If we have health left on the bar, update it
		if child.health_bar.value > 0:
			child.damage_bar.value = child.health_bar.value


func _on_max_health_changed(new_max_health: float, _prev_max_health: float) -> void:
	total_health = int(new_max_health)
	clear_sub_health_bars()
	init_boss_health_ui(int(new_max_health), sub_bar_count)


func check_after_setting_changed():
	visible = not GameManager.hide_ui


func show_ui() -> void:
	anim_player.play("show")


func hide_ui() -> void:
	anim_player.play("hide")


func change_status_label_visibility(status: BossCore.BossStatusEffect, set_to_visible: bool):
	var node_name: String = BossCore.BossStatusEffect.keys()[status].to_pascal_case()
	var found_node: Control = status_container.get_node(node_name)
	if found_node:
		found_node.visible = set_to_visible
