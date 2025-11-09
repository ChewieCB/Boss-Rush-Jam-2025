class_name StatusEffect

## Chance stuff are in decimal (0.5 = 50%)
enum PlayerStatEnum {
	NONE,
	RUN_SPEED_MODIFIER,
	DASH_SPEED_MODIFIER,
	IS_INVINVIBLE, # bool
	DAMAGE_REDUCTION, # 100 = 100% resist damage / take no damage
    JUMP_HEIGHT,
    DASH_IFRAME_DURATION,
	DASH_DURATION,
    CHIP_DROPRATE_MULTIPLIER,
    MIN_DAMAGE_VARIANCE,
    MAX_DAMAGE_VARIANCE,
    CRITICAL_HIT_CHANCE,
    CRITICAL_HIT_DAMAGE_MULTIPLIER,
    DODGE_CHANCE,
}
enum ModifyType {FLAT, PERCENTAGE, BOOL} # How it interact with base value


const INFINITE_DURATION = 100000

# NOTE: For simplicity, all stacking effect will be additively
# Ex: Buff A increased 25% speed, Buff B increased 100% speed, Debuff C reduced 20% speed
# Total to 25 + 100 - 20 = 105% increased speed.

var display_name: String
var status_code: String
var modified_stat: PlayerStatEnum
var modify_type: ModifyType
var value: float
var duration: float = 0
var is_bad_effect: bool
var status_icon: Texture2D
var show_duration_ui: bool = true
var show_value_on_ui: bool = false

func _to_string() -> String:
    var data = {
        "display_name": display_name,
        "status_code": status_code,
        "modified_stat": PlayerStatEnum.keys()[modified_stat],
        "modify_type": ModifyType.keys()[modify_type],
        "value": value,
        "duration": duration,
        "is_bad_effect": is_bad_effect,
        "show_duration_ui": show_duration_ui
    }
    return JSON.stringify(data)


# For debugging
# func _notification(what: int) -> void:
#     if what == NOTIFICATION_PREDELETE:
#         print("Effect {0} is deleted".format([status_code]))