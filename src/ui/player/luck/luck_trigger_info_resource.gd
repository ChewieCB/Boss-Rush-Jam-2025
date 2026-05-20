extends Resource
class_name LuckTriggerInfo


# TODO - update this as we add luck triggers
enum LuckTriggerIdEnum {
	GAMBLERS_PRECISION__LUCKY_SHOT,
	GAMBLERS_PRECISION__LET_IT_RIDE,
	EXPLOSIVE_BULLET__BADA_BING_BADA_BOOM,
	RICOCHET__RICOSHOT,
	BULLET_TIME__PASSTHROUGH,
	BULLET_TIME__FORESIGHT,
	LASER_GUIDED__ELABORATED_ANGLE,
	STICKY_BOMB__CLUSTER_BOMB,
	STICKY_BOMB__DANGER_CLOSE,
	MEDICAL_PAYOUT__PAYDAY,
}

@export var id: LuckTriggerIdEnum
@export var name: String
@export_multiline var desc: String
@export_multiline var message: String
