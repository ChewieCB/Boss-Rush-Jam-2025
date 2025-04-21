extends BossMap

@export var floor_pivot: AnimatableBody3D
@export var ROTATION_SPEED: float = 0.0:
	set(value):
		ROTATION_SPEED = value
		boss.wheel_rotation_speed = ROTATION_SPEED
var goal_rotation_speed: float = ROTATION_SPEED: set = set_goal_rotation_speed
# Floor segments array stores tuples of [mesh, collider] since we separate them
# for the purposes of the AnimatableBody3D rotation
var floor_segments: Array

@export var sfx_ambience: Array[AudioStream]
var current_sfx_ambient: AudioStream


func _ready() -> void:
	# Build the animatable body's collision from each wheel segment collider
	for segment in floor_pivot.get_children():
		var static_body: StaticBody3D = segment.get_child(0)
		var mesh: MeshInstance3D = static_body.get_child(0)
		var collider: CollisionShape3D = static_body.get_child(2)
		var new_collider = collider.duplicate()
		floor_pivot.add_child(new_collider)
		new_collider.global_position += static_body.global_position
		collider.disabled = true
		
		floor_segments.append([mesh, new_collider, mesh.global_position.y])
	boss.floor_segments = floor_segments
	
	super()


func _physics_process(delta) -> void:
	if ROTATION_SPEED != goal_rotation_speed:
		ROTATION_SPEED = lerp(ROTATION_SPEED, goal_rotation_speed, delta)
	floor_pivot.rotation.y += ROTATION_SPEED * delta
	boss.wheel_rotation_speed = ROTATION_SPEED


func shove_player(shove_force: float = 25.0) -> void:
	var shove_vector = player.global_position.direction_to(boss.global_position)
	player.dash_disabled = true
	#player.velocity = Vector3.ZERO
	player.vel_horizontal += Vector2(shove_vector.x, shove_vector.z) * shove_force
	player.vel_vertical += shove_vector.y * shove_force
	await get_tree().create_timer(0.5).timeout
	player.dash_disabled = false


func set_goal_rotation_speed(value: float) -> void:
	goal_rotation_speed = value


func _on_player_death() -> void:
	SoundManager.stop_ambient_sound(current_sfx_ambient, 0.5)
	super()


func _on_boss_defeated(_boss: BossCore) -> void:
	SoundManager.stop_ambient_sound(current_sfx_ambient, 0.5)
	super(_boss)


func _on_boss_trigger_volume_body_entered(body: Node3D) -> void:
	current_sfx_ambient = sfx_ambience.pick_random()
	SoundManager.play_ambient_sound(current_sfx_ambient, 0.5, "Ambience")
	super(body)
	shove_player()


func _on_killbox_area_body_entered(body: Node3D) -> void:
	if body is RouletteBall:
		body.destroy()
	elif "health_component" in body:
		if body is Player:
			body.fall_death()
		else:
			body.health_component.damage(9999999)
	else:
		body.queue_free()
