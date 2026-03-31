extends Node2D

var player_in_zone := false
var _credits_triggered := false

func _process(_delta: float) -> void:
	if player_in_zone and GameState.is_nox and Input.is_action_just_pressed("interact"):
		var dialogue = get_tree().get_first_node_in_group("dialogue")
		if dialogue:
			if GameState.skeleton_defeated and not _credits_triggered:
				_credits_triggered = true
				dialogue.d_file = "res://DIALOGUE/Village-Chief-Dialogue-After.json"
				dialogue.dialogue_finished.connect(_on_ending_dialogue_done, CONNECT_ONE_SHOT)
			else:
				dialogue.d_file = "res://DIALOGUE/Village-Chief-Dialogue.json"
			dialogue.start()

func _on_ending_dialogue_done() -> void:
	GameState.is_transitioning = true
	await SceneTransitions.fade_out(0.6)
	get_tree().change_scene_to_file("res://SCENES/Credits.tscn")

func _on_interaction_zone_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_zone = true
		GameState.player_in_interact_zone = true

func _on_interaction_zone_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_zone = false
		GameState.player_in_interact_zone = false
