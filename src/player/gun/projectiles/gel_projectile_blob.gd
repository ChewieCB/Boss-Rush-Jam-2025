extends GelProjectile

@export var tick_per_second: int = 5
@export var dot_damage_modifier = 0.5

@onready var damage_tick_timer: Timer = $DamageTickTimer

var stick_target = null


func init(start_pos: Vector3, dir: Vector3, _damage: int, ricochet_count: int, _speed: float, _max_range: float):
	super (start_pos, dir, _damage, ricochet_count, _speed, _max_range)
	activate(start_pos, dir)

func _on_area_3d_body_entered(body: Node3D) -> void:
	if sticked:
		return
	var calculated_damage = calculate_bullet_damage()
	if body is CharacterBody3D:
		if is_instance_valid(body):
			before_damage_applied.emit(body, self)
			calculated_damage = calculate_bullet_damage(false) # Recalculate damage after before_damage_applied effect
			apply_damage_to_health_component(body.health_component, calculated_damage)
			damage_applied.emit(calculated_damage, true, global_position)
			stick_target = body
		else:
			stick_target = null
	else:
		if body is Shield:
			body.impact(self.global_position)
			apply_damage_to_health_component(body.health_component, calculated_damage)
		elif "health_component" in body:
			apply_damage_to_health_component(body.health_component, calculated_damage)
	self.reparent.call_deferred(body)
	sticked = true
	damage_tick_timer.start(1.0 / tick_per_second)
	impacted.emit(self, true, global_position)
	life_timer.stop()
	stick_timer.start(stick_time)
	if found_hitscal_col:
		if global_position.distance_to(hitscan_col_point) < SNAP_STICK_DISTANCE:
			global_position = hitscan_col_point


func change_bullet_color(_new_color: Color):
	color_changed_count += 1 # Can't use super() here
	if color_changed_count > 1:
		var old_color = mesh_instance.mesh.material.get_shader_parameter("base_color")
		mesh_instance.mesh.material.set_shader_parameter("base_color", old_color.lerp(_new_color, 0.5))
		old_color = mesh_instance.mesh.material.get_shader_parameter("highlight_color")
		mesh_instance.mesh.material.set_shader_parameter("highlight_color", old_color.lerp(_new_color, 0.5))
	else:
		mesh_instance.mesh.material.set_shader_parameter("base_color", _new_color)
		mesh_instance.mesh.material.set_shader_parameter("highlight_color", _new_color)


func _on_stick_timer_timeout() -> void:
	life_timer.start(1)
	damage_tick_timer.stop()
	if ricochet_count_left > 0 and found_hitscal_col:
		sticked = false
		self.reparent.call_deferred(get_tree().get_root())
		ricochet()
	else:
		stop_elemental_particles()
		start_deflate = true


func _on_damage_tick_timer_timeout() -> void:
	if stick_target != null and stick_target is CharacterBody3D:
		before_damage_applied.emit(stick_target, self)
		var calculated_damage = int((calculate_bullet_damage() / tick_per_second) * dot_damage_modifier)
		stick_target.health_component.damage(calculated_damage)
		damage_applied.emit(calculated_damage, true, global_position)
