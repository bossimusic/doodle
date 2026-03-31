extends Node2D

func _ready() -> void:
	SFX.force_alternate_footsteps = true
	Music.stop_all(0.0)
	Music.set_track(0, "library", -6.0)
	SceneTransitions.fade_in()
	if GameState.library_intro_done:
		GEM_HUD.show_hud()
	if not GameState.library_intro_done:
		await get_tree().process_frame
		var dialogue = get_tree().get_first_node_in_group("dialogue")
		if dialogue:
			dialogue.d_file = "res://DIALOGUE/Library-Entry-Dialogue-Part1.json"
			dialogue.dialogue_finished.connect(_on_part1_done, CONNECT_ONE_SHOT)
			dialogue.start()

func _on_part1_done() -> void:
	GameState.library_intro_done = true
	GameState.save_checkpoint()
	var dialogue = get_tree().get_first_node_in_group("dialogue")
	if dialogue:
		dialogue.dialogue_finished.connect(_on_part2_done, CONNECT_ONE_SHOT)
		dialogue.start_next("res://DIALOGUE/Library-Entry-Dialogue-Part2.json")

func _on_part2_done() -> void:
	GEM_HUD.show_hud()
