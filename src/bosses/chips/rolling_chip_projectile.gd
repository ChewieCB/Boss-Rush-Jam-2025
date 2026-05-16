extends CharacterBody3D
class_name RollingChip

signal spin_finished

@export var health_component: HealthComponent
@export_group("Damage")
@export var damage: float = 15.0
@export var damage_cooldown: float = 0.1
@export_group("Spin Movement")
@export var spin_forward_buffer: float = 2.0
@export var spin_forward_check_distance: float = 128.0
@export var spin_forward_time: float = 0.8
@export var spin_hold_time: float = 0.3
@export var spin_reverse_time: float = 0.7
@export var spin_rotation_speed: float = 8.0
@export_group("SFX")
@export var sfx_rolling: Array[AudioStream]
@export var sfx_impact: Array[AudioStream]

@onready var mesh_pivot: Node3D = $MeshPivot
@onready var mesh: MeshInstance3D = $MeshPivot/MeshInstance3D
@onready var raycast: RayCast3D = $RayCast3D
@onready var hurtbox: Area3D = $MeshPivot/Hurtbox
@onready var hit_timer: Timer = $HitTImer
@onready var sfx_player: AudioStreamPlayer3D = $SFXPlayer
@onready var sfx_player_loop: AudioStreamPlayer3D = $SFXPlayerLoop

var wall_pos_sphere: MeshInstance3D
var target_pos_sphere: MeshInstance3D
var roll_start_pos_sphere: MeshInstance3D
var roll_mid_pos_sphere: MeshInstance3D
var roll_end_pos_sphere: MeshInstance3D


func _ready() -> void:
	sfx_player_loop.stream = sfx_rolling.pick_random()
	sfx_player_loop.play()

func init(_damage: float) -> void:
	damage = _damage


func get_point_before_wall() -> Vector3:
	# Get end point of forward spin
	var space_state = get_world_3d().direct_space_state
	var query_start: Vector3 = self.global_position + Vector3(0, 0.1, 0)
	var query_end: Vector3 = query_start - (self.global_transform.basis.z * spin_forward_check_distance)
	var query = PhysicsRayQueryParameters3D.create(
		query_start,
		query_end,
		int(pow(2, 1 - 1))
	)
	var arena_wall_pos = query_end
	var result = space_state.intersect_ray(query)
	if result:
		arena_wall_pos = result["position"]
	var target_point = arena_wall_pos + Vector3(0, 0, spin_forward_buffer).rotated(Vector3.UP, self.rotation.y)
	
	# Debug
	#wall_pos_sphere = draw_debug_sphere(arena_wall_pos, 1.0, Color.YELLOW)
	#target_pos_sphere = draw_debug_sphere(target_point, 1.0, Color.GREEN)
	
	return target_point


func roll_to_point(point: Vector3, time: float) -> void:
	# Toggle the hurtbox so we can have a double hit on rebound
	hurtbox.monitoring = false
	hurtbox.monitoring = true
	# Tween to the end point
	var half_way_point: Vector3 = self.global_position.lerp(point, 0.5)
	
	# Debug
	#roll_start_pos_sphere = draw_debug_sphere(self.global_position, 1.0, Color.DARK_BLUE)
	#roll_mid_pos_sphere = draw_debug_sphere(half_way_point, 1.0, Color.BLUE_VIOLET)
	#roll_end_pos_sphere = draw_debug_sphere(point, 1.0, Color.SKY_BLUE)
	
	var tween = get_tree().create_tween()
	tween.tween_property(self, "global_position", half_way_point, time / 2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	#tween.parallel().tween_property(mesh_pivot, "gldobal_rotation:x", -PI*spin_rotation_speed, time/2).set_trans(Tween.TRANS_CUBIC)
	tween.chain().tween_property(self, "global_position", point, time / 2).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	#tween.parallel().tween_property(mesh_pivot, "global_rotation:x", -PI*spin_rotation_speed, time/2).set_trans(Tween.TRANS_QUART)

	await tween.finished
	spin_finished.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		for elem in [
			wall_pos_sphere, target_pos_sphere, roll_start_pos_sphere,
			roll_mid_pos_sphere, roll_end_pos_sphere
		]:
			if elem:
				elem.queue_free()


func _physics_process(delta: float) -> void:
	mesh_pivot.rotate_x(spin_rotation_speed * delta)
	#velocity.y -= delta
	#move_and_slide()


func draw_debug_sphere(location: Vector3, size: float, color: Color) -> MeshInstance3D:
	# Will usually work, but you might need to adjust this.
	var scene_root = get_tree().root.get_children()[0]
	# Create sphere with low detail of size.
	var sphere = SphereMesh.new()
	sphere.radial_segments = 4
	sphere.rings = 4
	sphere.radius = size
	sphere.height = size * 2
	# Bright red material (unshaded).
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.flags_unshaded = true
	sphere.surface_set_material(0, material)

	# Add to meshinstance in the right place.
	var node = MeshInstance3D.new()
	node.mesh = sphere
	node.global_transform.origin = location
	scene_root.add_child(node)

	return node


func _on_hurtbox_body_entered(body: Node3D) -> void:
	if not hit_timer.is_stopped():
		return
	if body.health_component:
		sfx_player.stream = sfx_impact.pick_random()
		sfx_player.play()
		body.health_component.damage(damage)
		hit_timer.start(damage_cooldown)
