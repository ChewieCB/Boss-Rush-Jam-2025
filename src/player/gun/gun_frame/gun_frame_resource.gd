extends BaseDataResource
class_name GunFrameResource

enum GunFrameIdEnum {
	NONE,
	DEFAULT,
	SHOTGUN,
	SMG,
	SNIPER
}

@export var frame_name: String
@export var frame_id: GunFrameIdEnum
@export_multiline var frame_description: String
@export_multiline var flavour_text: String
@export var shop_ui_sprite: Texture2D
@export var reload_sfx: Array[AudioStream] = []
@export var shot_sfx: Array[AudioStream] = []
@export var frame_cost: int = 100
@export var base_damage: int = 20
@export var base_projectile_amount: int = 1
## Shot per second
@export var base_firerate: float = 2
@export var base_magazine_size: int = 10
@export var base_reload_time: float = 1
@export var base_spin_time: float = 1
## How spread out projectile can be from the aim center
@export var base_spread_angle: float = 0.5
## Projectile dont have travel time. Shot enemy is instanly damaged. If this ticked, ignore projectile_speed
@export var is_hitscan: bool
## How fast projectile travel. Ignored if is_hitscan ticked. Shouldn't higher than 100 or collision detecion
## will be an issue
@export var base_projectile_speed: float = 50
@export var recoil_amount: float = 0.03
## How much screenshake when player shot
@export var screenshake_amount: float = 0.2
@export var base_custom_projectile_prefab: PackedScene = null
