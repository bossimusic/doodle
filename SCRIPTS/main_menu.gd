extends Control

@onready var start_label: RichTextLabel = $RichTextLabel2
@onready var quit_label: RichTextLabel = $RichTextLabel3
@onready var y_btns: Array = [$YBtn0, $YBtn1]

var _selected: int = 0
var _labels: Array
var _initialized := false
var _nav_cooldown := 0.0

func _ready():
	_labels = [start_label, quit_label]
	Music.stop_all(0.0)
	Music.set_track(0, "main_menu")
	SceneTransitions.fade_in()
	_update_selection()
	_initialized = true

func _update_selection():
	for i in _labels.size():
		if i == _selected:
			_labels[i].add_theme_color_override("default_color", Color(1, 1, 0.3))
			y_btns[i].visible = true
		else:
			_labels[i].remove_theme_color_override("default_color")
			y_btns[i].visible = false
func _process(delta: float) -> void:
	if _nav_cooldown > 0:
		_nav_cooldown -= delta

func _input(event: InputEvent) -> void:
	if GameState.is_transitioning:
		return
	if event.is_action_pressed("move_right"):
		if _nav_cooldown <= 0:
			_selected = min(_selected + 1, _labels.size() - 1)
			_nav_cooldown = 0.25
			SFX.play("ui_select", -10.5)
			_update_selection()
	elif event.is_action_pressed("move_left"):
		if _nav_cooldown <= 0:
			_selected = max(_selected - 1, 0)
			_nav_cooldown = 0.25
			SFX.play("ui_select", -10.5)
			_update_selection()
	elif event is InputEventKey and event.pressed and not event.echo and _is_mapped_key(event):
		_confirm()
	elif event is InputEventJoypadButton and event.pressed:
		_confirm()
	elif event is InputEventMouseButton and event.pressed:
		_confirm()

func _is_mapped_key(event: InputEvent) -> bool:
	for action in InputMap.get_actions():
		if InputMap.action_has_event(action, event):
			return true
	return false

func _confirm():
	SFX.play("ui_confirm", -10.5)
	_labels[_selected].add_theme_color_override("default_color", Color.BLACK)
	GameState.is_transitioning = true
	Music.fade_to(0, -80.0, 1.0)
	if _selected == 0:
		await SceneTransitions.fade_out(1.0)
		get_tree().change_scene_to_file("res://SCENES/tutorial-doodle.tscn")
	else:
		GoodbyeScreen.show_goodbye()
