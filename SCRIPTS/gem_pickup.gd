extends Node2D

const INTERACT_RANGE := 40.0

@export var gem_id: String = "gem_1"

func _ready() -> void:
	if GameState.gems_permanent or GameState.gems_collected.has(gem_id) or GameState.has_dash:
		queue_free()
		return
	var base_y := position.y
	var tw := create_tween().set_loops()
	tw.tween_property(self, "position:y", base_y - 3.0, 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "position:y", base_y + 3.0, 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or global_position.distance_to(player.global_position) > INTERACT_RANGE:
		return
	GameState.gems_collected.append(gem_id)
	if GameState.gems_collected.size() >= 4:
		GameState.gems_permanent = true
	SFX.play("pickup_gem", -8.0)
	GameState.save_checkpoint()
	queue_free()
