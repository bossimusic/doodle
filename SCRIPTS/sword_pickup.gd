extends Node2D

var player_in_zone := false
var _waiting_for_dialogue := false
var _prompt_visible := false

@onready var _ctrl_sprite: Sprite2D = $Sprite2D
@onready var _labels: Array = [
	$PickupLabel,
	$PickupLabel2,
	$PickupLabel3,
	$PickupLabel4,
	$PickupLabel5,
]
@onready var _kb_labels: Array = [$ELabel, $ELabel2, $ELabel3, $ELabel4, $ELabel5]

func _update_prompt_indicator(v: bool) -> void:
	_prompt_visible = v
	var use_ctrl := GameState.is_using_controller
	_ctrl_sprite.visible = v and use_ctrl
	for lbl in _kb_labels:
		lbl.visible = v and not use_ctrl

func _set_visible(v: bool) -> void:
	for label in _labels:
		label.visible = v
	_update_prompt_indicator(v)

func _ready() -> void:
	if GameState.has_sword:
		queue_free()
		return
	GameState.input_scheme_changed.connect(func(_c): _update_prompt_indicator(_prompt_visible))
	_set_visible(false)

func _process(_delta: float) -> void:
	if _waiting_for_dialogue or not player_in_zone:
		return
	if Input.is_action_just_pressed("interact"):
		_trigger_dialogue()

func _trigger_dialogue() -> void:
	_waiting_for_dialogue = true
	_set_visible(false)
	var dialogue = get_tree().get_first_node_in_group("dialogue")
	if dialogue:
		dialogue.d_file = "res://DIALOGUE/Sword-Pickup-Dialogue.json"
		dialogue.start()
		dialogue.dialogue_finished.connect(_on_dialogue_done, CONNECT_ONE_SHOT)
	else:
		_on_dialogue_done()

func _on_dialogue_done() -> void:
	GameState.has_sword = true
	GameState.checkpoint_position = global_position
	GameState.save_checkpoint()
	queue_free()

func _on_pickup_zone_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_zone = true
		_set_visible(true)

func _on_pickup_zone_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_zone = false
		_set_visible(false)
