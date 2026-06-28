extends PhysicsBody3D
class_name Vendor

signal inventory_opened
signal inventory_closed

@onready var dialogue_label: Label3D = $Label3D
@onready var ui_layer: CanvasLayer = $UI
@onready var shop_ui: ShopUI = $UI/ShopUI
@onready var health_component: HealthComponent = $HealthComponent
@onready var interact_area: Area3D = $InteractArea

@export var has_shop: bool = true
@export var interact_text: String = "Shop"
@export var interact_dist: float = 5.0

@export var interact_dialogue: Array[String]
@export var exit_dialogue: Array[String]
@export var hurt_dialogue: Array[String]
@export var purchase_dialogue: Array[String]
@export var too_expensive_dialogue: Array[String]


func _ready() -> void:
	health_component.hurt.connect(_on_hurt)
	shop_ui.inventory_opened.connect(inventory_opened.emit)
	shop_ui.inventory_closed.connect(inventory_closed.emit)
	dialogue_label.text = ""
	
	ui_layer.visible = false
	ui_layer.process_mode = Node.PROCESS_MODE_DISABLED
	shop_ui.visible = false
	
	GameManager.barrel_purchased.connect(_on_purchase.unbind(1))
	GameManager.barrel_too_expensive.connect(_on_too_expensive.unbind(1))
	GameManager.gun_frame_purchased.connect(_on_purchase.unbind(1))
	GameManager.gun_frame_too_expensive.connect(_on_too_expensive.unbind(1))


func interact() -> void:
	if has_shop:
		if shop_ui.visible:
			ui_layer.visible = false
			ui_layer.process_mode = Node.PROCESS_MODE_DISABLED
		else:
			ui_layer.visible = true
			ui_layer.process_mode = Node.PROCESS_MODE_INHERIT
		
		shop_ui.toggle()
		GameManager.player.input_dir = Vector2.ZERO
		GameManager.player.vel_horizontal = Vector2.ZERO
		GameManager.player.velocity = Vector3.ZERO


func get_interact_text() -> String:
	return interact_text


func show_dialogue(dialogue: String) -> void:
	dialogue_label.modulate.a = 0.0
	dialogue_label.text = dialogue
	var tween = get_tree().create_tween()
	tween.tween_property(dialogue_label, "modulate:a", 1.0, 0.5)
	shop_ui.set_shopkeeper_chat(dialogue)


func _on_hurt() -> void:
	if hurt_dialogue:
		show_dialogue(hurt_dialogue.pick_random())


func _on_purchase() -> void:
	if purchase_dialogue:
		show_dialogue(purchase_dialogue.pick_random())


func _on_too_expensive() -> void:
	if too_expensive_dialogue:
		show_dialogue(too_expensive_dialogue.pick_random())


func _on_body_entered(body: Node3D) -> void:
	if interact_dialogue:
		if body is Player:
			show_dialogue(interact_dialogue.pick_random())


func _on_body_exited(body: Node3D) -> void:
	if exit_dialogue:
		if body is Player:
			show_dialogue(exit_dialogue.pick_random())
			#if shop_ui.visible:
				#shop_ui.close()
