extends Area2D

@export var target_scene: String = "res://SCENES/village.tscn"

var player_in_zone := false
var _transitioning := false
var _dialogue_cooldown := false

@onready var _labels: Array = [
	$PromptLabel,
	$PromptLabel2,
	$PromptLabel3,
	$PromptLabel4,
	$PromptLabel5,
]
var _sprite: AnimatedSprite2D = null
var _robot_fixed_last := false

func _set_visible(v: bool) -> void:
	for label in _labels:
		label.visible = v

func _update_animation() -> void:
	if not _sprite:
		return
	var frames := _sprite.sprite_frames
	var target := "activated" if GameState.robot_fixed else "not-activated"
	if frames and frames.has_animation(target):
		_sprite.play(target)
	elif frames and frames.has_animation("default"):
		_sprite.play("default")

func _ready() -> void:
	for child in get_children():
		if child is AnimatedSprite2D:
			_sprite = child
			break
	_robot_fixed_last = GameState.robot_fixed
	_set_visible(false)
	_update_animation()

func _process(_delta: float) -> void:
	if GameState.robot_fixed != _robot_fixed_last:
		_robot_fixed_last = GameState.robot_fixed
		_update_animation()
	if _dialogue_cooldown:
		_dialogue_cooldown = false
		return
	if _transitioning or not player_in_zone:
		return
	if Input.is_action_just_pressed("interact"):
		if not GameState.robot_fixed:
			return
		if GameState.is_nox or GameState.is_frog:
			var dialogue = get_tree().get_first_node_in_group("dialogue")
			if dialogue and not GameState.is_in_dialogue:
				dialogue.d_file = "res://DIALOGUE/Assistant-Teleport-Illegal-Dialogue.json"
				dialogue.dialogue_finished.connect(
					func(): _dialogue_cooldown = true, CONNECT_ONE_SHOT)
				dialogue.start()
		else:
			_teleport()

func _teleport() -> void:
	_transitioning = true
	GameState.is_transitioning = true
	_set_visible(false)
	await SceneTransitions.fade_out()
	GameState.arriving_via_teleport = true
	get_tree().change_scene_to_file(target_scene)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_zone = true
		GameState.player_in_interact_zone = true
		_set_visible(true)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_zone = false
		GameState.player_in_interact_zone = false
		_set_visible(false)
