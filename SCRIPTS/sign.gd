extends Area2D

var _prompt_visible := false
var _ctrl_sprite: Sprite2D = null
var _kb_labels: Array = []

func _update_prompt_indicator(v: bool) -> void:
	_prompt_visible = v
	if _ctrl_sprite == null:
		return
	var use_ctrl := GameState.is_using_controller
	_ctrl_sprite.visible = v and use_ctrl
	for lbl in _kb_labels:
		lbl.visible = v and not use_ctrl

func _set_visible(v: bool) -> void:
	for child in get_children():
		if child is CanvasItem and child != _ctrl_sprite and not (child in _kb_labels):
			child.visible = v
	_update_prompt_indicator(v)

func _ready():
	for child in get_children():
		if child is Sprite2D:
			_ctrl_sprite = child
			break
	if _ctrl_sprite:
		for n in ["ELabel", "ELabel2", "ELabel3", "ELabel4", "ELabel5"]:
			var node = get_node_or_null(n)
			if node:
				_kb_labels.append(node)
	GameState.input_scheme_changed.connect(func(_c): _update_prompt_indicator(_prompt_visible))
	_set_visible(false)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_set_visible(true)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_set_visible(false)
