@tool
extends StaticBody3D
class_name RisingPlatform


@onready var marker: Marker3D = $Marker3D
var time: float = randf_range(0.0, 100.0)
var noise := FastNoiseLite.new()
@export var float_strength: float = 0.2
@export var float_frequency: float = 5.0
@export var bob_strength: float = 2.0
@export var bob_frequency: float = 2.0
@export var noise_strength: float = 0.001
var cached_transform: Transform3D
@export var floating: bool = false:
	set(value):
		floating = value
		if floating:
			cached_transform = self.global_transform
			set_physics_process(true)
		else:
			set_physics_process(false)
			if cached_transform:
				self.global_transform = cached_transform


func _ready() -> void:
	self.rotation.x = 0.0
	self.rotation.y = randf_range(0.0, 2*PI)
	self.rotation.z = 0.0
	noise.seed = randi()
	noise.frequency = 0.5
	set_physics_process(false)


func raise(height: float, time: float) -> void:
	await change_height(height, time)
	set_physics_process(true)


func lower(time: float) -> void:
	await change_height(0, time)
	set_physics_process(false)


func change_height(new_height: float, time: float) -> void:
	var tween: Tween = get_tree().create_tween()
	tween.parallel().tween_property(self, "global_position:y", new_height, time)
	await tween.finished


func _physics_process(delta: float) -> void:
	time += delta
	var noise_val = noise.get_noise_1d(time * 5.0) * noise_strength
	self.position.y += sin(time * float_frequency) * float_strength * delta
	self.rotation.x += noise_val + sin(time * bob_frequency) * bob_strength * delta
	self.rotation.z += noise_val + sin(time * bob_frequency) * bob_strength * delta
