extends Resource
class_name BarrelDataResource

enum BarrelIdEnum {
    NONE,
    TEST,
    ARCHETYPE,
    DYNAMIC_ADVANTAGE,
    FOOL_ROLLER,
    PROJECTILE_COUNT,
    TRICKSHOT,
}

@export var barrel_id: BarrelIdEnum
@export var image_icon: Texture2D
@export var prefab: PackedScene