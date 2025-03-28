extends Control

signal loading_finished(scene: PackedScene)

var lobby_scene_path: String = "res://src/maps/lobby/Lobby.tscn"

var can_transition: bool = false

@onready var progress_bar: ProgressBar = $CenterContainer/ProgressBar


func _ready() -> void:
	ResourceLoader.load_threaded_request(lobby_scene_path)


func start_loading() -> void:
	self.visible = true
	can_transition = true


func _process(delta: float) -> void:
	var progress = []
	ResourceLoader.load_threaded_get_status(lobby_scene_path, progress)
	progress_bar.value = progress[0] * 100
	
	if progress[0] == 1 and can_transition:
		var packed_scene = ResourceLoader.load_threaded_get(lobby_scene_path)
		loading_finished.emit(packed_scene)
