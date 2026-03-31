extends Node

func _ready() -> void:
	SFX.force_alternate_footsteps = false
	Music.cache_tracks(["tutorial_pre", "tutorial_post"])
	var settle := 0.2 if GameState.spawn_position != Vector2.ZERO else 0.0
	SceneTransitions.fade_in(1.0, settle)
	_start_music()

func _start_music() -> void:
	SFX.enabled = true
	Music.stop_all(0.0)
	if GameState.robot_fixed:
		Music.set_track(0, "tutorial_post", 4.0)
	else:
		_wait_for_landing()

func _wait_for_landing() -> void:
	var player = get_tree().get_first_node_in_group("player")
	SFX._next_land_sound = "land_hard"
	SFX._next_land_volume = -12.0
	while player and not player.is_on_floor():
		await get_tree().process_frame
	Music.set_track(0, "tutorial_pre", 2.0)
	Music.set_track(1, "tutorial_post", -80.0)
