extends CharacterBody2D

@onready var dialogue = get_tree().get_first_node_in_group("dialogue")

@export var doodle_d_file: String

var player_in_chat_zone = false

func _process(_delta):
	if player_in_chat_zone and Input.is_action_just_pressed("interact"):
		if not GameState.is_nox and not GameState.is_frog and doodle_d_file != "":
			dialogue.d_file = doodle_d_file
			dialogue.start()


func _on_chat_deduction_area_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_chat_zone = true
		GameState.player_in_interact_zone = true

func _on_chat_deduction_area_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_chat_zone = false
		GameState.player_in_interact_zone = false
