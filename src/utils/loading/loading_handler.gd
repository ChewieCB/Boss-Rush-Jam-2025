extends Node

signal loading_finished(scene: PackedScene)

var current_scene_path: String:
	set(value):
		current_scene_path = value
		ResourceLoader.load_threaded_request(current_scene_path)

var can_transition: bool = false


func start_loading(scene_name: String = "") -> void:
	ScreenTransition.set_loading_detail_text("Loading %s" % [scene_name])
	ScreenTransition.transition_out()
	
	await ScreenTransition.transition_finished
	
	ScreenTransition.set_loading_visible()
	can_transition = true


func load_scene(packed_scene: PackedScene) -> void:
	can_transition = false
	loading_finished.emit(packed_scene)
	get_tree().change_scene_to_packed(packed_scene)
	ScreenTransition.set_loading_visible(false)
	ScreenTransition.transition_in()
	await ScreenTransition.transition_finished


func _process(delta: float) -> void:
	if current_scene_path:
		var progress = []
		ResourceLoader.load_threaded_get_status(current_scene_path, progress)
		ScreenTransition.progress_bar.value = progress[0] * 100
		
		if progress[0] == 1 and can_transition:
			var packed_scene = ResourceLoader.load_threaded_get(current_scene_path)
			load_scene(packed_scene)
