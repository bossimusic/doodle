extends Node2D

enum State { BROKEN, FIXED }
const REPAIR_FALLBACK_DURATION := 1.5

var state := State.BROKEN
var player_in_zone := false
var is_repairing := false

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var error_label: Label = $ErrorLabel
@onready var inspect_label: Label = $InspectLabel
@onready var inspect_label2: Label = $InspectLabel2
@onready var inspect_label4: Label = $InspectLabel4
@onready var inspect_label5: Label = $InspectLabel5
@onready var inspect_label6: Label = $InspectLabel6
@onready var dialogue = $DIALOGUE

var _inspect_visible := false

func _ready() -> void:
	error_label.visible = false
	GameState.input_scheme_changed.connect(func(_c): _update_prompt_indicator(_inspect_visible))
	_set_inspect_visible(false)
	if GameState.robot_fixed:
		state = State.FIXED
		_play_anim("Idle")
	else:
		_play_anim("Error-Idle")
	dialogue.dialogue_finished.connect(_on_dialogue_finished)

func _process(_delta: float) -> void:
	if is_repairing:
		return
	if player_in_zone and not GameState.is_in_dialogue and Input.is_action_just_pressed("interact"):
		_handle_interact()

func _handle_interact() -> void:
	if not GameState.is_nox and not GameState.is_frog:
		_set_inspect_visible(false)
		dialogue.d_file = "res://DIALOGUE/Assistant-Doodle-Dialogue.json"
		dialogue.start()
		return
	if state == State.FIXED:
		_set_inspect_visible(false)
		dialogue.d_file = "res://DIALOGUE/Assistant-NPC-Dialogue.json"
		dialogue.start()
		return
	if not GameState.has_memory:
		_show_error()
	else:
		_begin_repair()

func _show_error() -> void:
	_set_inspect_visible(false)
	SFX.play("assistant_error", -4.4)
	dialogue.d_file = "res://DIALOGUE/No-Memory-Dialogue.json"
	dialogue.start()

func _on_dialogue_finished() -> void:
	if dialogue.d_file == "res://DIALOGUE/Assistant-NPC-Dialogue.json":
		GameState.assistant_dialogue_done = true
	if player_in_zone:
		_set_inspect_visible(true)

func _begin_repair() -> void:
	is_repairing = true
	_set_inspect_visible(false)
	_play_anim("Fixing")
	Music.fade_to(0, -80.0, REPAIR_FALLBACK_DURATION)
	Music.fade_to(1, 4.0, REPAIR_FALLBACK_DURATION)
	await get_tree().create_timer(REPAIR_FALLBACK_DURATION).timeout
	_play_anim("Idle")
	GameState.robot_fixed = true
	state = State.FIXED
	is_repairing = false

@onready var _x_button: Sprite2D = $Sprite2D

func _update_prompt_indicator(v: bool) -> void:
	_inspect_visible = v
	_x_button.visible = v and GameState.is_using_controller

func _set_inspect_visible(v: bool) -> void:
	inspect_label.visible = v
	inspect_label2.visible = v
	inspect_label4.visible = v
	inspect_label5.visible = v
	inspect_label6.visible = v
	_update_prompt_indicator(v)

func _play_anim(anim_name: String) -> void:
	if anim.sprite_frames == null:
		return
	if anim.sprite_frames.has_animation(anim_name):
		anim.play(anim_name)

func _on_interaction_zone_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_zone = true
		GameState.player_in_interact_zone = true
		_set_inspect_visible(true)

func _on_interaction_zone_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_zone = false
		GameState.player_in_interact_zone = false
		_set_inspect_visible(false)
