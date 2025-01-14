extends Resource
class_name BarrelDataResource

## Keep adding at the bottmom, dont add at the middle of list
enum BarrelIdEnum {
    NONE,
    TEST,
    ARCHETYPE,
    DYNAMIC_ADVANTAGE,
    FOOL_ROLLER,
    PROJECTILE_COUNT,
    TRICKSHOT,
    ARCHETYPE_SHOTGUN_SPEC
}

@export var barrel_id: BarrelIdEnum
@export var barrel_name: String
@export_multiline var barrel_desc: String
@export var barrel_image: Texture2D
@export var barrel_prefab: PackedScene