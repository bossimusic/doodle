extends Area2D

var _player_in_zone := false
var _activated := false
var _prompt_visible := false

@onready var _ctrl_sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var _flame: AnimatedSprite2D = get_node_or_null("Flame")
@onready var _labels: Array = ([
	get_node_or_null("PickupLabel"),
	get_node_or_null("PickupLabel2"),
	get_node_or_null("PickupLabel3"),
	get_node_or_null("PickupLabel4"),
	get_node_or_null("PickupLabel5"),
] as Array).filter(func(n): return n != null)
@onready var _kb_labels: Array = ([
	get_node_or_null("ELabel"),
	get_node_or_null("ELabel2"),
	get_node_or_null("ELabel3"),
	get_node_or_null("ELabel4"),
	get_node_or_null("ELabel5"),
] as Array).filter(func(n): return n != null)

func _update_prompt_indicator(v: bool) -> void:
	_prompt_visible = v
	var use_ctrl := GameState.is_using_controller
	if _ctrl_sprite:
		_ctrl_sprite.visible = v and use_ctrl
	for lbl in _kb_labels:
		lbl.visible = v and not use_ctrl

func _set_labels_visible(v: bool) -> void:
	for label in _labels:
		label.visible = v
	_update_prompt_indicator(v)

func _ready() -> void:
	GameState.input_scheme_changed.connect(func(_c): _update_prompt_indicator(_prompt_visible))
	if _flame:
		_flame.animation_finished.connect(_on_flame_animation_finished)
		if GameState.respawned_from_death and GameState.checkpoint_position == global_position:
			_activated = true
			_flame.play("idle")
		else:
			_flame.hide()
	elif GameState.respawned_from_death and GameState.checkpoint_position == global_position:
		_activated = true
	GameState.respawned_from_death = false
	_set_labels_visible(false)

func _process(_delta: float) -> void:
	if _activated or not _player_in_zone:
		return
	if Input.is_action_just_pressed("interact"):
		_activate()

func _activate() -> void:
	_activated = true
	GameState.checkpoint_position = global_position
	GameState.save_checkpoint()
	SFX.play("checkpoint", -12.0)
	_set_labels_visible(false)
	if _flame:
		_flame.show()
		_flame.play("start")

func _on_flame_animation_finished() -> void:
	if _flame and _flame.animation == "start":
		_flame.play("idle")

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not _activated:
		_player_in_zone = true
		_set_labels_visible(true)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_zone = false
		_set_labels_visible(false)
