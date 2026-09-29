extends VBoxContainer

@export var gauge_scene: PackedScene
@export var buildups_root: Node


func _ready() -> void:
	if not buildups_root:
		return
	for child in buildups_root.get_children():
		if child is StatusBuildupComponent:
			var gauge: StatusBuildupGauge = gauge_scene.instantiate()
			add_child(gauge)
			gauge.bind(child)
