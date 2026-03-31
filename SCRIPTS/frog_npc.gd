extends Node2D

var player_in_zone := false
var _dialogue_cooldown := false

@onready var _labels: Array = [
	$InteractZone/PickupLabel,
	$InteractZone/PickupLabel2,
	$InteractZone/PickupLabel3,
	$InteractZone/PickupLabel4,
	$InteractZone/PickupLabel5,
]

func _ready() -> void:
	for lbl in _labels:
		lbl.visible = false

func _process(_delta: float) -> void:
	if _dialogue_cooldown:
		_dialogue_cooldown = false
		return
	if player_in_zone and GameState.has_sword and not GameState.is_in_dialogue and Input.is_action_just_pressed("interact"):
		var dialogue = get_tree().get_first_node_in_group("dialogue")
		if dialogue:
			dialogue.d_file = "res://DIALOGUE/Frog-Dialogue.json"
			dialogue.dialogue_finished.connect(func():
				_dialogue_cooldown = true
				if not GameState.has_frog_form:
					GameState.has_frog_form = true
					var player = get_tree().get_first_node_in_group("player")
					if player:
						player.set_frog_form(true)
			, CONNECT_ONE_SHOT)
			dialogue.start()

func _on_interact_zone_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_zone = true
		GameState.player_in_interact_zone = true
		for lbl in _labels:
			lbl.visible = true

func _on_interact_zone_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_zone = false
		GameState.player_in_interact_zone = false
		for lbl in _labels:
			lbl.visible = false
