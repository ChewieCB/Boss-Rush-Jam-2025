extends Resource
class_name LuckTriggerInfo


# TODO - update this as we add luck triggers
enum LuckTriggerIdEnum {
	GAMBLERS_PRECISION__LUCKY_SHOT,
	GAMBLERS_PRECISION__LET_IT_RIDE,
}

@export var id: LuckTriggerIdEnum
@export var name: String
@export_multiline var desc: String
@export_multiline var message: String
