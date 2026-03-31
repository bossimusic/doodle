extends Node2D

func _ready():
	GameState.full_reset()
	Music.stop_all(0.0)
	Music.set_track(0, "home_credits")
	SceneTransitions.fade_in(1.5)

func _unhandled_input(event: InputEvent) -> void:
	if GameState.is_transitioning:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("jump") \
			or event.is_action_pressed("advance_dialogue") or event.is_action_pressed("skip_dialogue"):
		GameState.is_transitioning = true
		await SceneTransitions.fade_out()
		get_tree().change_scene_to_file("res://SCENES/MainMenu.tscn")
