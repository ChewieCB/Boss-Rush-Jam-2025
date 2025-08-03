extends TextureRect


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	GameManager.setting_ui.setting_changed.connect(refresh_after_setting_changed)
	refresh_after_setting_changed()

func refresh_after_setting_changed():
	visible = not GameManager.hide_ui