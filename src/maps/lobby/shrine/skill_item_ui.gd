extends TextureRect
class_name SkillItemUI

enum SkillId {
	NONE,
	HOT_HAND,
	LUCKY_SHOT,
	LUCKY_CRIT, # Replaced, Inreased crit mult from 2.0x to 2.5x
	DOUBLE_DOWN,
	IOU,
	INSURANCE,
	POKER_FACE,
	BLINDSPOT,
	PLOT_ARMOR,
	JACKPOT,
	BLESSED_CHIP,
	HIGH_ROLLER # Replaced, spin barrel with higher cost will restore more hp

}

@export var skill_name: String
@export_multiline var description: String
@export var skill_id_enum: SkillId
@export var prerequisite_skills: Array[SkillId]
