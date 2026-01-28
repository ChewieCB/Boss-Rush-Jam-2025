extends Resource
class_name BossDifficultyProfile

@export var boss_id: BossCore.BossIdEnum
@export_multiline var boss_quote: String
@export var ante_names: Array[String] = ["", "", "", "", ""]
@export var boss_risk_reward_mult: float = 1.0
