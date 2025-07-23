extends StaticBody3D

@onready var interact_area: Area3D = $InteractArea
@onready var skill_tree_ui: SkillTreeUI = $UI/SkillTreeUI

func _ready() -> void:
	skill_tree_ui.visible = false


func interact() -> void:
	skill_tree_ui.toggle()
	GameManager.player.input_dir = Vector2.ZERO
	GameManager.player.vel_horizontal = Vector2.ZERO
	GameManager.player.velocity = Vector3.ZERO


func _on_interact_area_body_entered(_body: Node3D) -> void:
	return

func _on_interact_area_body_exited(body: Node3D) -> void:
	if body is Player:
		skill_tree_ui.close()