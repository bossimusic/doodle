extends Node2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var _prompt_labels: Array = []

@export var patrol_enabled := true
@export var patrol_tiles := 5      # patrol range in tiles (1 tile = 16px)
@export var invert_flip := false   # set true for skeletons with scale.x = -1
@export var idle_anim := "Waiting"

var player_in_zone := false
var hit_count := 0
var _state := "waiting"   # "waiting" | "waking" | "patrol" | "attack" | "hit" | "dead"

var _patrol_origin: float
var _patrol_dir: int = 1
var _patrol_range: float
const PATROL_SPEED := 40.0

func _set_prompt_visible(v: bool) -> void:
	for lbl in _prompt_labels:
		lbl.visible = v

func _ready() -> void:
	for child in get_children():
		if child is Label and child.name.begins_with("PromptLabel"):
			_prompt_labels.append(child)
	if GameState.skeleton_defeated or name in GameState.skeletons_killed:
		_state = "dead"
		queue_free()
		return
	_patrol_origin = position.x
	_patrol_range = patrol_tiles * 16.0
	_state = "waiting"
	anim.play(idle_anim)

func _process(delta: float) -> void:
	if _state == "waiting" and player_in_zone:
		if not GameState.is_in_dialogue and Input.is_action_just_pressed("interact"):
			_startled()
	if _state != "patrol":
		return
	if not patrol_enabled:
		return
	position.x += _patrol_dir * PATROL_SPEED * delta
	anim.flip_h = ((_patrol_dir < 0) != invert_flip)
	if position.x >= _patrol_origin + _patrol_range:
		_patrol_dir = -1
	elif position.x <= _patrol_origin - _patrol_range:
		_patrol_dir = 1

func _startled() -> void:
	_set_prompt_visible(false)
	var dialogue = get_tree().get_first_node_in_group("dialogue")
	if not dialogue:
		return
	if GameState.is_nox:
		_state = "waking"
		hurtbox.monitoring = false
		dialogue.d_file = "res://DIALOGUE/Skeleton-Nox-Dialogue.json"
		dialogue.dialogue_finished.connect(_on_startled_dialogue_done, CONNECT_ONE_SHOT)
	else:
		dialogue.d_file = "res://DIALOGUE/Skeleton-Doodle-Dialogue.json"
	dialogue.start()

func _on_startled_dialogue_done() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var dir = sign(player.global_position.x - global_position.x)
		var tween = create_tween()
		tween.tween_property(player, "global_position:x",
				player.global_position.x + dir * 80.0, 0.2)
		player.velocity.y = -250.0
		player.is_jumping = true
		player.animated_sprite_2d.play(player._anim("JUMP_LOOP"))
	for skeleton in get_tree().get_nodes_in_group("skeleton"):
		if skeleton != self:
			skeleton.wake_up()
	anim.play("Back-Idle")
	await anim.animation_finished
	if _state == "dead":
		return
	hurtbox.monitoring = true
	_state = "patrol"
	anim.play("Walk" if patrol_enabled else "Idle")

func wake_up() -> void:
	if _state != "waiting":
		return
	_state = "waking"
	anim.play("Back-Idle")
	await anim.animation_finished
	if _state == "dead":
		return
	_state = "patrol"
	anim.play("Walk" if patrol_enabled else "Idle")

const ATTACK_HIT_FRAME := 7  # frame of "new_animation" when the hit lands

func _attack() -> void:
	_state = "attack"
	var player = get_tree().get_first_node_in_group("player")
	if player:
		anim.flip_h = (player.position.x < position.x) != invert_flip
	var hit_dealt := [false]  # Array used as mutable closure variable (GDScript limitation)
	var frame_conn = func():
		if not hit_dealt[0] and _state == "attack" and anim.frame >= ATTACK_HIT_FRAME:
			hit_dealt[0] = true
			var p = get_tree().get_first_node_in_group("player")
			if player_in_zone and p:
				var dir = sign(p.global_position.x - global_position.x)
				var tween = create_tween()
				tween.tween_property(p, "global_position:x",
						p.global_position.x + dir * 48.0, 0.2)
				p.take_damage(1)
	anim.frame_changed.connect(frame_conn)
	anim.play("new_animation")
	await anim.animation_finished
	if anim.frame_changed.is_connected(frame_conn):
		anim.frame_changed.disconnect(frame_conn)
	if _state == "dead":
		return
	_state = "patrol"
	anim.play("Walk" if patrol_enabled else "Idle")
	if player_in_zone and GameState.is_nox:
		_attack()

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if _state == "dead" or _state == "hit" or area.collision_layer != 4:
		return
	hit_count += 1
	if hit_count >= 2:
		_die()
	else:
		_hit()

func _hit() -> void:
	_state = "hit"
	hurtbox.set_deferred("monitoring", false)
	var tween = create_tween()
	tween.tween_property(anim, "modulate", Color(4, 4, 4), 0.05)
	tween.tween_property(anim, "modulate", Color(1, 1, 1), 0.1)
	anim.play("Hit")
	SFX.play("enemy_hit", 0.8)
	await anim.animation_finished
	hurtbox.set_deferred("monitoring", true)
	_state = "patrol"
	anim.play("Walk" if patrol_enabled else "Idle")
	if player_in_zone and GameState.is_nox:
		_attack()

func _die() -> void:
	_state = "dead"
	hurtbox.set_deferred("monitoring", false)
	SFX.play("enemy_hit", 0.8)
	GameState.skeletons_killed.append(name)
	anim.play("Death")
	await anim.animation_finished
	anim.play("Disappear body")
	await get_tree().create_timer(1.0).timeout
	anim.play("Gone")
	if anim.sprite_frames.get_frame_count("Gone") > 0:
		await anim.animation_finished
	if get_tree().get_nodes_in_group("skeleton").size() <= 1:
		GameState.skeleton_defeated = true
		GameState.skeleton_defeated_changed.emit()
	queue_free()

func _on_interact_zone_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_zone = true
		GameState.player_in_interact_zone = true
		if _state == "waiting":
			_set_prompt_visible(true)
		elif _state == "patrol" and GameState.is_nox:
			_attack()

func _on_interact_zone_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_zone = false
		GameState.player_in_interact_zone = false
		_set_prompt_visible(false)
