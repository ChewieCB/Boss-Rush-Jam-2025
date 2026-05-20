extends StaticBody3D
class_name Bell

signal finished
signal destroyed(bell: Bell)

@export var damage: float = 20.0
@export var explosion_prefab: PackedScene
@export var dust_cloud_prefab: PackedScene
@export_group("SFX")
@export var sfx_bell_full: Array[AudioStream]
@export var sfx_bell_land: Array[AudioStream]
@export var sfx_bell_impact: Array[AudioStream]

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var collider: CollisionShape3D = $CollisionShape3D
@onready var hurtbox: Area3D = $Hurtbox
@onready var hurtbox_collider: CollisionShape3D = $Hurtbox/CollisionShape3D
@onready var sfx_player: AudioStreamPlayer3D = $SFXPlayer
@onready var raycast: RayCast3D = $RayCast3D

const PERSIST_TIME = 1.0
const TREMOR_INTENSITY = 0.3
const CLOSE_TREMOR_DISTANCE = 20
const CLOSE_TREMOR_INTENSITY = 0.6

var size: float = 1
var floor_y: float = 0.0


func init(_damage: float, _size: float):
	damage = _damage
	size = _size

func drop() -> void:
	activate()
	if raycast.is_colliding():
		floor_y = raycast.get_collision_point().y
	
	mesh.visible = true

	sfx_player.stream = sfx_bell_full.pick_random()
	sfx_player.play()
	var tween: Tween = get_tree().create_tween()
	# 1.04s is the timestamp of the impact in the full bell sfx samples
	tween.tween_property(self, "global_position:y", floor_y, 1.04)
	tween.tween_callback(destroy)


func destroy() -> void:
	# Impact
	var dust_cloud_vfx = dust_cloud_prefab.instantiate()
	get_tree().get_root().add_child(dust_cloud_vfx)
	dust_cloud_vfx.global_position = global_position + Vector3(0, 1, 0)
	sfx_player.stream = sfx_bell_land.pick_random()
	sfx_player.play()
	# If player near, shake their camera stronger
	var player_distance_to_bell = GameManager.player.global_position.distance_to(global_position)
	if player_distance_to_bell < CLOSE_TREMOR_DISTANCE:
		GameManager.player.player_camera.add_trauma(CLOSE_TREMOR_INTENSITY)
	else:
		GameManager.player.player_camera.add_trauma(TREMOR_INTENSITY)

	await get_tree().create_timer(PERSIST_TIME).timeout

	# Explode and destroyed
	sfx_player.stream = sfx_bell_impact.pick_random()
	sfx_player.play()
	var explosion_vfx: ExplosionParticles = explosion_prefab.instantiate()
	get_tree().get_root().add_child(explosion_vfx)
	explosion_vfx.global_position = global_position + Vector3(0, 1, 0)
	explosion_vfx.scale_factor = size
	explosion_vfx.explode()
	
	var tween = get_tree().create_tween()
	tween.tween_property(mesh.mesh.surface_get_material(0), "albedo_color:a", 0, 0.3).set_trans(Tween.TRANS_EXPO)
	tween.tween_callback(_on_destroyed)


func _on_destroyed() -> void:
	destroyed.emit(self)


func _on_hurtbox_body_entered(body: Node3D) -> void:
	if body is Player:
			body.health_component.damage(damage)
		# TODO - damage boss? Allow kiting?


func activate() -> void:
	collider.set_deferred("disabled", false)
	hurtbox_collider.set_deferred("disabled", false)
	hurtbox.monitoring = true
	hurtbox.monitorable = true
	raycast.enabled = true
	self.visible = true
	mesh.mesh.surface_get_material(0).albedo_color.a = 1.0
	self.process_mode = Node.PROCESS_MODE_INHERIT


func deactivate() -> void:
	collider.set_deferred("disabled", true)
	hurtbox_collider.set_deferred("disabled", true)
	raycast.enabled = false
	hurtbox.monitoring = false
	hurtbox.monitorable = false
	self.visible = false
	# Prevent cutoff
	if sfx_player.playing:
		await sfx_player.finished
	self.process_mode = Node.PROCESS_MODE_DISABLED
