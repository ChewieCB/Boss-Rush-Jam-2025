extends GelProjectile

@export var tick_per_second: int = 5
@export var dot_damage_modifier = 0.5

@onready var damage_tick_timer: Timer = $DamageTickTimer

var stick_target = null

func _on_area_3d_body_entered(body: Node3D) -> void:
	if sticked:
		return
	var calculated_damage = calculate_bullet_damage()
	if body is CharacterBody3D:
		if is_instance_valid(body):
			before_damage_applied.emit(body, self)
			body.health_component.damage(calculated_damage)
			damage_applied.emit(calculated_damage, true, global_position)
			stick_target = body
		else:
			stick_target = null
	else:
		if body is Shield:
			body.impact(self.global_position)
			body.health_component.damage(calculated_damage)
		elif "health_component" in body:
			body.health_component.damage(calculated_damage)
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
		trail.material_override.albedo_color = trail.material_override.albedo_color.lerp(_new_color, 0.5)
		trail.material_override.emission = trail.material_override.emission.lerp(_new_color, 0.5)
	else:
		mesh_instance.mesh.material.set_shader_parameter("base_color", _new_color)
		mesh_instance.mesh.material.set_shader_parameter("highlight_color", _new_color)
		trail.material_override.albedo_color = Color(_new_color.r, _new_color.g, _new_color.b, 0.5)
		trail.material_override.emission = _new_color


func _on_stick_timer_timeout() -> void:
	life_timer.start()
	damage_tick_timer.stop()
	if ricochet_count_left > 0 and found_hitscal_col:
		sticked = false
		damage_tick_timer.stop()
		self.reparent.call_deferred(get_tree().get_root())
		ricochet()
	else:
		start_deflate = true


func _on_damage_tick_timer_timeout() -> void:
	if stick_target != null and stick_target is CharacterBody3D:
		before_damage_applied.emit(stick_target, self)
		var calculated_damage = int((calculate_bullet_damage() / tick_per_second) * dot_damage_modifier)
		stick_target.health_component.damage(calculated_damage)
		damage_applied.emit(calculated_damage, true, global_position)
