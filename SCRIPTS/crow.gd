extends AnimatedSprite2D

func _ready() -> void:
	sprite_frames.set_animation_loop("idle", true)
	play("idle")
	_schedule_eat()

func _schedule_eat() -> void:
	await get_tree().create_timer(randf_range(12.0, 18.0)).timeout
	play("eat")
	await animation_finished
	play("idle")
	_schedule_eat()
