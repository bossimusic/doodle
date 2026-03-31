extends Area2D

var player_in_zone := false
var _transitioning := false
var _dialogue_cooldown := false

@onready var _prompt_labels: Array = []

func _set_prompt_visible(v: bool) -> void:
	for lbl in _prompt_labels:
		lbl.visible = v

func _ready() -> void:
	for child in get_children():
		if child is Label and child.name.begins_with("PromptLabel"):
			_prompt_labels.append(child)
	_set_prompt_visible(false)

func _process(_delta: float) -> void:
	if _dialogue_cooldown:
		_dialogue_cooldown = false
		return
	if _transitioning or not player_in_zone or GameState.is_in_dialogue:
		return
	if Input.is_action_just_pressed("interact"):
		if GameState.skeleton_defeated:
			var dialogue = get_tree().get_first_node_in_group("dialogue")
			if not GameState.door_dialogue_shown:
				if dialogue and not GameState.is_in_dialogue:
					GameState.door_dialogue_shown = true
					dialogue.d_file = "res://DIALOGUE/Village-Chief-Dialogue.json"
					dialogue.dialogue_finished.connect(func():
						_dialogue_cooldown = true
						call_deferred("_enter")
					, CONNECT_ONE_SHOT)
					dialogue.start()
			else:
				_enter()
		else:
			var dialogue = get_tree().get_first_node_in_group("dialogue")
			if dialogue and not GameState.is_in_dialogue:
				dialogue.d_file = "res://DIALOGUE/Village-Chief-Dialogue-Locked.json"
				dialogue.dialogue_finished.connect(
					func(): _dialogue_cooldown = true, CONNECT_ONE_SHOT)
				dialogue.start()

func _enter() -> void:
	_transitioning = true
	GameState.is_transitioning = true
	await SceneTransitions.fade_out(0.25)
	get_tree().change_scene_to_file("res://SCENES/home.tscn")

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_zone = true
		GameState.player_in_interact_zone = true
		_set_prompt_visible(true)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_zone = false
		GameState.player_in_interact_zone = false
		_set_prompt_visible(false)
