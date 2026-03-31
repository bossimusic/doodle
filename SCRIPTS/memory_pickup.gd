extends Node2D

var player_in_zone := false
var base_y: float




func _ready() -> void:
	if GameState.robot_fixed:
		queue_free()
		return
	base_y = position.y
	_start_bob()

func _start_bob() -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(self, "position:y", base_y - 3.0, 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position:y", base_y + 3.0, 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _process(_delta: float) -> void:
	if player_in_zone and Input.is_action_just_pressed("interact"):
		GameState.has_memory = true
		queue_free()

func _on_pickup_zone_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_zone = true

func _on_pickup_zone_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_zone = false
