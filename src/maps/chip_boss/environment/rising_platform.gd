extends StaticBody3D
class_name RisingPlatform


@onready var marker: Marker3D = $Marker3D


func _ready() -> void:
	add_to_group("rising_platforms")
	marker.add_to_group("boss_aoe_marker")


func raise(height: float, time: float) -> void:
	await change_height(height, time)


func lower(time: float) -> void:
	await change_height(-marker.global_position.y, time)


func change_height(new_height: float, time: float) -> void:
	var tween: Tween = get_tree().create_tween()
	tween.parallel().tween_property(self, "global_position:y", new_height, time)
	await tween.finished
