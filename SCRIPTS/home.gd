extends Node2D

func _ready() -> void:
	SFX.force_alternate_footsteps = true
	GameState.has_sword = true
	GameState.has_frog_form = true
	GameState.robot_fixed = true
	GameState.skeleton_defeated = true
	Music.stop_all(0.0)
	Music.set_track(0, "home_credits", -6.0)
	SceneTransitions.fade_in()
	call_deferred("_apply_nox_form")

func _apply_nox_form() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.set_nox_form(true)
