extends Resource
class_name BarrelDataResource

## Keep adding new item at the bottom, dont add at the middle of list
enum BarrelIdEnum {
	NONE,
	TEST,
	ARCHETYPE,
	DYNAMIC_ADVANTAGE,
	FOOL_ROLLER,
	PROJECTILE_COUNT,
	TRICKSHOT,
	ARCHETYPE_SHOTGUN_SPEC,
	ROULETTE_BOSS,
	ARCHETYPE_RAILGUN_SPEC,
	ARCHETYPE_AUTOMATIC_SPEC,
	PIT_BOSS_BARREL,
	BARTENDER_BOSS_BARREL,
	DELAYED_GRATIFICATION
}

@export var barrel_id: BarrelIdEnum
@export var barrel_name: String
@export_multiline var barrel_desc: String
@export var barrel_image: Texture2D
@export var barrel_cost: int = 200
@export var barrel_prefab: PackedScene
