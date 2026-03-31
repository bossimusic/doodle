extends Area2D

var _transitioning := false

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and not _transitioning and not GameState.is_transitioning:
		_transitioning = true
		call_deferred("_exit")

func _exit() -> void:
	GameState.is_transitioning = true
	GameState.arriving_from_home = true
	await SceneTransitions.fade_out(0.25)
	get_tree().change_scene_to_file("res://SCENES/village.tscn")
