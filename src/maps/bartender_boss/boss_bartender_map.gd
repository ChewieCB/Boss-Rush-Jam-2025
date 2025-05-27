extends BossMap

@export_group("SFX")
@export var sfx_fire_start: AudioStream
@export var sfx_fire_loop: AudioStream


func _ready() -> void:
	boss.fire_started.connect(_on_fire_started)
	super()


func _on_fire_started() -> void:
	var fire_sfx = SoundManager.play_ambient_sound(sfx_fire_start, 0.2, "SFX")
	fire_sfx.finished.connect(func():
		SoundManager.play_ambient_sound(sfx_fire_loop, 0.1, "SFX")
	)


func _on_player_death() -> void:
	SoundManager.stop_ambient_sound(sfx_fire_loop, 0.5)
	super()


func _on_boss_defeated(_boss: BossCore) -> void:
	SoundManager.stop_ambient_sound(sfx_fire_loop, 0.5)
	super(_boss)
