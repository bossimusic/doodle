extends CanvasLayer

@onready var _bg: ColorRect = $ColorRect
@onready var _you_died: Label = $YouDied
@onready var _press_any: Label = $PressAny

var _active := false

func _ready() -> void:
	layer = 15
	visible = false

func show_dead() -> void:
	_active = false
	visible = true
	_you_died.visible = false
	_press_any.visible = false
	_bg.modulate.a = 0.0
	Music.stop_all(0.8, 0.5)
	Music.play_death_audio()
	var tw := create_tween()
	tw.tween_property(_bg, "modulate:a", 1.0, 0.8)
	await tw.finished
	_you_died.visible = true
	await get_tree().create_timer(0.5).timeout
	_press_any.visible = true
	_active = true

func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_restart()
	elif event is InputEventJoypadButton and event.pressed:
		_restart()

func _restart() -> void:
	_active = false
	visible = false
	Music.stop_death_audio()
	GameState.reset()
	HP_HUD.refresh()
	if GameState.checkpoint_position != Vector2.ZERO:
		GameState.spawn_position = GameState.checkpoint_position
	GameState.respawned_from_death = true
	get_tree().reload_current_scene()
