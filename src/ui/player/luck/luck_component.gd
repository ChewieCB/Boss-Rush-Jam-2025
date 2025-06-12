extends BaseComponent
class_name LuckComponent

signal luck_changed(new_luck: float, prev_luck: float)
signal luck_diff(diff: float)
signal luck_maxed()

@export_category("Luck")
@export var max_luck: float = 100

var high_luck_threshold: float = 0.75
var luck_loss_modifier: float = 1.0
var luck_gain_modifier: float = 1.0

var current_luck: float:
	set(value):
		if not enabled:
			return
		# Cache previous value so we can do dynamic luck bars
		var prev_luck = current_luck
		current_luck = clamp(value, 0, max_luck)
		var diff = current_luck - prev_luck
		current_luck_ratio = current_luck / max_luck
		luck_diff.emit(diff)
		luck_changed.emit(current_luck, prev_luck)
		if current_luck == 0:
			# TODO - do we want anything to trigger at 0 luck?
			pass
		elif current_luck == max_luck:
			luck_maxed.emit()
			LuckHandler.max_luck_decay_buffer()
var current_luck_ratio: float = current_luck / max_luck


func _ready() -> void:
	initialize_luck()
	LuckHandler.luck_increased.connect(increase_luck)
	LuckHandler.luck_decreased.connect(decrease_luck)


func decrease_luck(_reduction: float) -> void:
	_reduction = round(_reduction * luck_loss_modifier)
	if enabled:
		current_luck -= _reduction
	check_for_luck_buffs()

func increase_luck(_luck: float) -> void:
	if enabled:
		_luck = round(_luck * luck_gain_modifier)
		current_luck += _luck
	check_for_luck_buffs()


func initialize_luck() -> void:
	current_luck = 0.0

# If we switched to using skill tree system instead of just linear level, just
# replace the if-level with if-has-skill

func check_for_luck_buffs():
	if GameManager.player_level >= 2:
		# Dash +0.2s iframe
		if current_luck_ratio >= high_luck_threshold:
			create_and_add_buff("High luck: Improved dash", "high_luck_increased_dash_iframe",
			StatusEffect.PlayerStatEnum.DASH_IFRAME_DURATION, 0.2, StatusEffect.ModifyType.FLAT)
		else:
			GameManager.player.remove_status_effect_by_name("high_luck_increased_dash_iframe")
	if GameManager.player_level >= 3:
		# Chip drop 30% more
		if current_luck_ratio >= high_luck_threshold:
			create_and_add_buff("High luck: Improved chip droprate", "high_luck_increased_chip_droprate",
			StatusEffect.PlayerStatEnum.CHIP_DROPRATE_MULTIPLIER, 0.3, StatusEffect.ModifyType.FLAT)
		else:
			GameManager.player.remove_status_effect_by_name("high_luck_increased_chip_droprate")
	if GameManager.player_level >= 4:
		# 5% Crit chance
		pass
	if GameManager.player_level >= 5:
		# Better 
		pass
	if GameManager.player_level >= 6:
		pass


func create_and_add_buff(display_name: String, status_code: String,
	modified_stat: StatusEffect.PlayerStatEnum, value: float, modify_type: StatusEffect.ModifyType):
	var status_effect = StatusEffect.new()
	status_effect.display_name = display_name
	status_effect.status_code = status_code
	status_effect.modified_stat = modified_stat
	status_effect.value = value
	status_effect.modify_type = modify_type
	status_effect.duration = StatusEffect.INFINITE_DURATION
	status_effect.is_bad_effect = false
	status_effect.show_duration_ui = false
	status_effect.show_value_on_ui = false
	GameManager.player.add_status_effect(status_effect)