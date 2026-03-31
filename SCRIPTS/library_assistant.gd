extends CharacterBody2D

const INTERACT_RANGE := 40.0

var _cooldown := 0.0

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
		return
	if GameState.is_in_dialogue:
		return
	if not (GameState.is_nox or GameState.is_frog):
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or global_position.distance_to(player.global_position) > INTERACT_RANGE:
		return
	if Input.is_action_just_pressed("interact"):
		_start_dialogue()

func _start_dialogue() -> void:
	_cooldown = 0.3
	var dialogue = get_tree().get_first_node_in_group("dialogue")
	if not dialogue:
		return
	if GameState.has_dash:
		dialogue.d_file = "res://DIALOGUE/Library-Assistant-Done.json"
	elif GameState.gems_collected.size() >= 4:
		dialogue.d_file = "res://DIALOGUE/Library-Assistant-Trade-Part1.json"
		dialogue.dialogue_finished.connect(_on_trade_part1_done, CONNECT_ONE_SHOT)
	else:
		dialogue.d_file = "res://DIALOGUE/Library-Assistant-Need-Gems.json"
	dialogue.dialogue_finished.connect(func(): _cooldown = 0.5, CONNECT_ONE_SHOT)
	dialogue.start()

func _on_trade_part1_done() -> void:
	GameState.has_dash = true
	GameState.robot_fixed = true
	GameState.save_checkpoint()
	var dialogue = get_tree().get_first_node_in_group("dialogue")
	if dialogue:
		dialogue.dialogue_finished.connect(func(): _cooldown = 0.5, CONNECT_ONE_SHOT)
		dialogue.start_next("res://DIALOGUE/Library-Assistant-Trade-Part2.json")
		SFX.play("library_transfer", -2.5)
