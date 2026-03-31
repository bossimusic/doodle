extends Node

signal input_scheme_changed(is_controller: bool)
@warning_ignore("unused_signal")
signal skeleton_defeated_changed
var is_using_controller: bool = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F:
			if OS.get_name() == "Web":
				JavaScriptBridge.eval("document.querySelector('canvas').requestFullscreen()")
			else:
				var mode := DisplayServer.window_get_mode()
				if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				else:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	var was := is_using_controller
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		is_using_controller = true
	elif event is InputEventKey or event is InputEventMouseButton:
		is_using_controller = false
	if is_using_controller != was:
		emit_signal("input_scheme_changed", is_using_controller)

var pause_intro_shown := false
var has_memory := false
var robot_fixed := false
var assistant_dialogue_done := false
var has_sword := false
var has_frog_form := false
var has_dash := false
var is_nox := false
var is_frog := false
var is_in_dialogue := false
var player_in_interact_zone := false
var spawn_position := Vector2.ZERO
var arriving_via_teleport := false
var arriving_from_home := false
var arriving_from_library := false
var is_transitioning := false
var skeleton_defeated := false
var skeletons_killed: Array = []
var gems_collected: Array = []
var gems_permanent: bool = false  # set when all 4 collected; never cleared by reset()
var door_dialogue_shown := false
var nox_forgot_shown := false
var player_hp: int = 5
var max_hp: int = 5
var checkpoint_position: Vector2 = Vector2.ZERO
var checkpoint_state: Dictionary = {}
var respawned_from_death: bool = false
var boss_defeated: bool = false
var library_intro_done: bool = false

func _quit() -> void:
	if OS.get_name() == "Web":
		JavaScriptBridge.eval("window.location.reload()")
	else:
		get_tree().quit()

func reset() -> void:
	# Always reset transient state
	player_hp = max_hp
	player_in_interact_zone = false
	is_nox = false
	is_frog = false
	is_in_dialogue = false
	arriving_via_teleport = false
	arriving_from_home = false
	arriving_from_library = false
	spawn_position = Vector2.ZERO
	# has_sword always persists — never touched here
	# Restore checkpointed flags (defaults to false/empty if no checkpoint activated yet)
	has_memory              = checkpoint_state.get("has_memory", false)
	robot_fixed             = checkpoint_state.get("robot_fixed", false)
	assistant_dialogue_done = checkpoint_state.get("assistant_dialogue_done", false)
	has_frog_form           = checkpoint_state.get("has_frog_form", false)
	has_dash                = checkpoint_state.get("has_dash", false)
	skeleton_defeated       = checkpoint_state.get("skeleton_defeated", false)
	skeletons_killed        = checkpoint_state.get("skeletons_killed", []).duplicate()
	if not gems_permanent:
		gems_collected = []
	boss_defeated           = checkpoint_state.get("boss_defeated", false)
	library_intro_done      = checkpoint_state.get("library_intro_done", false)
	door_dialogue_shown     = checkpoint_state.get("door_dialogue_shown", false)
	nox_forgot_shown        = checkpoint_state.get("nox_forgot_shown", false)
	pause_intro_shown       = checkpoint_state.get("pause_intro_shown", false)

func full_reset() -> void:
	checkpoint_state = {}
	checkpoint_position = Vector2.ZERO
	spawn_position = Vector2.ZERO
	has_memory = false
	robot_fixed = false
	assistant_dialogue_done = false
	has_frog_form = false
	has_dash = false
	has_sword = false
	skeleton_defeated = false
	skeletons_killed = []
	gems_collected = []
	gems_permanent = false
	boss_defeated = false
	library_intro_done = false
	door_dialogue_shown = false
	nox_forgot_shown = false
	pause_intro_shown = false
	is_nox = false
	is_frog = false
	is_in_dialogue = false
	is_transitioning = false
	arriving_via_teleport = false
	arriving_from_home = false
	arriving_from_library = false
	player_hp = max_hp
	player_in_interact_zone = false
	respawned_from_death = false

func save_checkpoint() -> void:
	checkpoint_state = {
		"has_memory": has_memory,
		"robot_fixed": robot_fixed,
		"assistant_dialogue_done": assistant_dialogue_done,
		"has_frog_form": has_frog_form,
		"has_dash": has_dash,
		"skeleton_defeated": skeleton_defeated,
		"skeletons_killed": skeletons_killed.duplicate(),
		"gems_collected": gems_collected.duplicate(),
		"boss_defeated": boss_defeated,
		"library_intro_done": library_intro_done,
		"door_dialogue_shown": door_dialogue_shown,
		"nox_forgot_shown": nox_forgot_shown,
		"pause_intro_shown": pause_intro_shown,
	}
