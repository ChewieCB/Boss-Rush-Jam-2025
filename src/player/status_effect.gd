class_name StatusEffect

enum StatusEffectModifyType {FLAT, PERCENTAGE, BOOL}

const INFINITE_DURATION = 100000

var display_name: String
var status_code: String
var modified_stat_name: String # Which stat this status affects (e.g., "strength", "run_speed_modifier").
var modify_type: StatusEffectModifyType
var value: float
var duration: float = 0
var is_bad_effect: bool
var status_icon: Texture2D

func _to_string() -> String:
    var data = {
        "display_name": display_name,
        "status_code": status_code,
        "modified_stat_name": modified_stat_name,
        "modify_type": modify_type,
        "value": value,
        "duration": duration,
        "is_bad_effect": is_bad_effect,
    }
    return JSON.stringify(data)


# For debugging
# func _notification(what: int) -> void:
#     if what == NOTIFICATION_PREDELETE:
#         print("Effect {0} is deleted".format([status_code]))