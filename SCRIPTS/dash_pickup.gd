extends Area2D

var _player_in_zone := false

func _ready() -> void:
	if GameState.has_dash:
		queue_free()

func _process(_delta: float) -> void:
	if not _player_in_zone or GameState.is_in_dialogue:
		return
	if Input.is_action_just_pressed("interact"):
		_collect()

func _collect() -> void:
	GameState.has_dash = true
	queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_zone = true
		GameState.player_in_interact_zone = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_zone = false
		GameState.player_in_interact_zone = false
