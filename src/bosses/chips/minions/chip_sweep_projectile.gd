extends Area3D
class_name ChipSweepProjectile

signal chips_placed
signal chips_removed

@onready var mesh: MeshInstance3D = $MeshBase
@onready var collider: CollisionShape3D = $ColliderBase

var last_chip_pos: Vector3
@export var sweep_offset: float = 1.0
@export var anim_time: float = 0.05
var spawned_chips := []

@export var sweep_damage: float = 10.0


func add_chips(chip_count: int) -> void:
	for i in range(chip_count):
		var chip_tuple: Array = await _add_chip()
		spawned_chips.append(chip_tuple)
	chips_placed.emit()
	self.set_deferred("monitoring", false)


func remove_chips() -> void:
	for i in range(spawned_chips.size()):
		var chip_tuple = spawned_chips.pop_back()
		var _mesh = chip_tuple[0]
		var _collider = chip_tuple[1]
		var tween: Tween = get_tree().create_tween()
		tween.tween_property(_mesh, "global_position", _mesh.global_position - Vector3(0, 0, sweep_offset), anim_time).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(_mesh, "global_position",  _collider.global_position - Vector3(0, 0, sweep_offset), anim_time).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(_collider, "scale", Vector3.ZERO, anim_time).set_ease(Tween.EASE_OUT)
		
		await tween.finished
		
		_mesh.queue_free()
		_collider.queue_free()
	
	chips_removed.emit()


func _add_chip() -> Array:
	var new_mesh: MeshInstance3D = mesh.duplicate()
	var new_collider: CollisionShape3D = collider.duplicate()
	add_child(new_mesh)
	add_child(new_collider)
	new_collider.disabled = false
	new_mesh.visible = true
	new_mesh.scale = Vector3.ZERO
	
	var new_pos := Vector3(0, 0.3, -sweep_offset)
	if last_chip_pos:
		new_pos = last_chip_pos + Vector3(0, 0, -sweep_offset)
	
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(new_mesh, "position", new_pos, anim_time).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(new_collider, "position", new_pos, anim_time).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(new_mesh, "scale", mesh.scale, anim_time).set_ease(Tween.EASE_OUT)
	last_chip_pos = new_pos
	
	await tween.finished
	
	return [new_mesh, new_collider]


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		body.health_component.damage(sweep_damage)
