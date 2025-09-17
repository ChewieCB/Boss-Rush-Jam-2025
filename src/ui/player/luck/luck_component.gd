extends BaseComponent
class_name LuckComponent

signal luck_changed(new_luck: float, prev_luck: float)
signal luck_diff(diff: float)
signal luck_maxed()

@export_category("Luck")
@export var max_luck: float = 100

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
	check_for_high_luck_buffs()

func increase_luck(_luck: float) -> void:
	if enabled:
		_luck = round(_luck * luck_gain_modifier)
		current_luck += _luck
	check_for_high_luck_buffs()


func initialize_luck() -> void:
	current_luck = 0.0

func check_for_high_luck_buffs():
	var player_base_stat = GameManager.player.base_stats

	if is_high_luck():
		# Hot Hand: 5% increased minimum damage per level
		if GameManager.player_skill_dict.has(SkillItemUI.SkillIdEnum.HOT_HAND):
			var increased_min_dmg = 0.05 * GameManager.player_skill_dict[SkillItemUI.SkillIdEnum.HOT_HAND]
			GameManager.create_and_add_status_effect("Hot Hand", "hot_hand_buff",
			StatusEffect.PlayerStatEnum.MIN_DAMAGE_VARIANCE, increased_min_dmg, StatusEffect.ModifyType.FLAT)

		# Lucky Shot: increased crit chance
		if GameManager.player_skill_dict.has(SkillItemUI.SkillIdEnum.LUCKY_SHOT):
			var increased_crit = 0
			match GameManager.player_skill_dict[SkillItemUI.SkillIdEnum.LUCKY_SHOT]:
				1:
					increased_crit = 0.04
				2:
					increased_crit = 0.07
				3:
					increased_crit = 0.1
				4:
					increased_crit = 0.15
			GameManager.create_and_add_status_effect("Lucky Shot", "lucky_shot_buff",
			StatusEffect.PlayerStatEnum.CRITICAL_HIT_CHANCE, increased_crit, StatusEffect.ModifyType.FLAT)

		# Blindspot: 10% increased dash iframe duration per level
		if GameManager.player_skill_dict.has(SkillItemUI.SkillIdEnum.BLINDSPOT):
			var increased_dash_duration = player_base_stat[StatusEffect.PlayerStatEnum.DASH_DURATION] * 0.1 * \
				GameManager.player_skill_dict[SkillItemUI.SkillIdEnum.BLINDSPOT]
			GameManager.create_and_add_status_effect("Blindspot", "blindspot_buff",
			StatusEffect.PlayerStatEnum.DASH_IFRAME_DURATION, increased_dash_duration, StatusEffect.ModifyType.FLAT)
	else:
		GameManager.player.remove_status_effect_by_name("hot_hand_buff")
		GameManager.player.remove_status_effect_by_name("lucky_shot_buff")
		GameManager.player.remove_status_effect_by_name("blindspot_buff")


func get_high_luck_threshold():
	var calculated_value = ((GameManager.BASE_PLAYER_LUCK_THRESHOLD * 100) - (GameManager.player_level - 1) / 100.0)
	return calculated_value

func is_high_luck():
	return current_luck_ratio >= get_high_luck_threshold()