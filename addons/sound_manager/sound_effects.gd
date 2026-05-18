extends "./abstract_audio_player_pool.gd"


func play(resource: AudioStream, override_bus: String = "") -> AudioStreamPlayer:
	var player = prepare(resource, override_bus)
	player.call_deferred("play")
	return player


func stop(resource: AudioStream) -> void:
	for player in busy_players:
		if player.stream == resource:
			player.call_deferred("stop")


# 3D Sound Support

var available_players_3d: Array[AudioStreamPlayer3D] = []
var busy_players_3d: Array[AudioStreamPlayer3D] = []
var default_pool_size_3d := 4


func play_3d(resource: AudioStream, position: Vector3, override_bus: String = "") -> AudioStreamPlayer3D:
	var player = get_available_player_3d()
	player.stream = resource
	player.bus = override_bus if override_bus != "" else bus
	player.volume_db = linear_to_db(1.0)
	player.pitch_scale = 1
	player.global_position = position

	player.call_deferred("play")
	return player


func get_available_player_3d() -> AudioStreamPlayer3D:
	if available_players_3d.size() == 0:
		increase_pool_3d()
	var player = available_players_3d.pop_front()
	while not is_instance_valid(player):
		increase_pool_3d(true)
		if available_players_3d.size() == 0:
			push_error("Failed to create valid 3D audio player")
			return null
		player = available_players_3d.pop_front()
	busy_players_3d.append(player)
	return player


func increase_pool_3d(force = false) -> void:
	# See if we can reclaim a rogue busy player
	if not force:
		for player in busy_players_3d:
			if not player.playing:
				mark_player_as_available_3d(player)
				return

	# Otherwise, add a new player
	var player := AudioStreamPlayer3D.new()
	add_child(player)
	available_players_3d.append(player)
	player.bus = bus
	player.finished.connect(_on_player_3d_finished.bind(player))


func mark_player_as_available_3d(player: AudioStreamPlayer3D) -> void:
	if busy_players_3d.has(player):
		busy_players_3d.erase(player)

	if available_players_3d.size() >= default_pool_size_3d:
		player.queue_free()
	elif not available_players_3d.has(player):
		available_players_3d.append(player)


func _on_player_3d_finished(player: AudioStreamPlayer3D) -> void:
	mark_player_as_available_3d(player)
