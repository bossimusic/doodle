extends Area2D

@export var instant_restart: bool = false

@onready var timer: Timer = $Timer

func _on_body_entered(body):
	if body.is_in_group("player"):
		timer.start()
	

func _on_timer_timeout() -> void:
	if GameState.is_transitioning:
		return
	if instant_restart:
		GameState.is_transitioning = true
		await SceneTransitions.fade_out(0.25)
		GameState.reset()
		if GameState.checkpoint_position != Vector2.ZERO:
			GameState.spawn_position = GameState.checkpoint_position
		GameState.respawned_from_death = true
		HP_HUD.refresh()
		get_tree().reload_current_scene()
	else:
		while GameState.player_hp > 0:
			GameState.player_hp -= 1
			await get_tree().create_timer(0.07).timeout
		HP_HUD.show_dead()
		DeadScreen.show_dead()
