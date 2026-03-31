extends Node

@onready var _hint: Label = $UI/Content/HintText

func _ready():
	SceneTransitions.fade_in()
	_update_hint()
	GameState.input_scheme_changed.connect(func(_c): _update_hint())

func _update_hint() -> void:
	if GameState.is_using_controller:
		_hint.text = "* press Y to continue! *"
	else:
		_hint.text = "* press SPACE to continue! *"

func _input(event: InputEvent) -> void:
	if GameState.is_transitioning:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_SPACE:
		_confirm()
	elif event is InputEventJoypadButton and event.pressed \
			and event.button_index == JOY_BUTTON_Y:
		_confirm()

func _confirm():
	GameState.is_transitioning = true
	await SceneTransitions.fade_out()
	get_tree().change_scene_to_file("res://SCENES/MainMenu.tscn")
