extends Control

const HINT_DELAY := 30.0

var _hint_timer := 0.0
var _hint_active := false
var _hint_shown := false

func _ready():
	SFX.force_alternate_footsteps = false
	GameState.has_sword = true
	SceneTransitions.fade_in()
	_start_music()
	GameState.skeleton_defeated_changed.connect(_on_skeletons_defeated)

func _start_music() -> void:
	Music.stop_all(0.0)
	var state_key: String
	if GameState.has_dash:
		state_key = "village_fixed"
	else:
		state_key = "village_broken"
	Music.start_synced_pair("village_conga", state_key)

func _on_skeletons_defeated() -> void:
	pass

func _process(delta: float) -> void:
	if _hint_shown or GameState.skeleton_defeated:
		return
	var count = get_tree().get_nodes_in_group("skeleton").size()
	if not _hint_active and count == 1:
		_hint_active = true
		_hint_timer = HINT_DELAY
	if _hint_active:
		if get_tree().get_nodes_in_group("skeleton").size() == 0:
			_hint_active = false
			return
		_hint_timer -= delta
		if _hint_timer <= 0.0:
			_hint_shown = true
			var dialogue = get_tree().get_first_node_in_group("dialogue")
			if dialogue and not GameState.is_in_dialogue:
				dialogue.d_file = "res://DIALOGUE/Skeleton-Hint-Dialogue.json"
				dialogue.start()


func _on_skeleton_zone_body_entered(body: Node) -> void:
	if not body.is_in_group("player") or GameState.nox_forgot_shown:
		return
	GameState.nox_forgot_shown = true
	var dialogue = get_tree().get_first_node_in_group("dialogue")
	if dialogue and not GameState.is_in_dialogue:
		dialogue.d_file = "res://DIALOGUE/Nox-Forgot-Dialogue.json"
		dialogue.start()
