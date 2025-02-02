class_name Buff

enum BuffType {FLAT, PERCENTAGE}
enum StackType {ADDITIVE, MULTIPLICATIVE}

var buff_name: String
var stat_name: String # Which stat this buff affects (e.g., "strength", "speed").
var value: float # The buff's value.
var buff_type: int # BuffType.FLAT or BuffType.PERCENTAGE.
var stack_type: int # StackType.ADDITIVE or StackType.MULTIPLICATIVE.
var duration: float = 0
