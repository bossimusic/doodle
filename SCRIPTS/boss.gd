extends Node2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var wave_anim: AnimatedSprite2D = $Wave/AnimatedSprite2D
@onready var _big_hitbox: Area2D = $"Big Attack Hitbox"
@onready var _wave_part1: CollisionShape2D = $"Wave/Hitbox/part-1"
@onready var _wave_part1_1: CollisionShape2D = $Wave/Hitbox/part1_1
@onready var _wave_part1_2: CollisionShape2D = $Wave/Hitbox/part1_2
@onready var _wave_part2: CollisionShape2D = $"Wave/Hitbox/part-2"
@onready var _wave_part3: CollisionShape2D = $"Wave/Hitbox/part-3"
@onready var _wave_part4: CollisionShape2D = $"Wave/Hitbox/part-4"

func _set_hurtbox_shape(state: String) -> void:
	$Hurtbox/ShapeIdle.set_deferred("disabled", false)
	$Hurtbox/ShapeAttackA.set_deferred("disabled", state != "attack_a")
	$Hurtbox/ShapeAttackB.set_deferred("disabled", state != "attack_b")

# ── Tuning ──────────────────────────────────────────────────
const WAVE_TRAVEL_DURATION := 0.4
const MOVE_SPEED     := 22.0
const AGGRO_RANGE    := 360.0
const ATTACK_A_RANGE := 130.0
const ATTACK_B_RANGE := 60.0
const HEAL_RANGE     := 280.0
const DAMAGE_A       := 1
const DAMAGE_B       := 2
const KNOCKBACK_A    := 80.0
const KNOCKBACK_B    := 150.0
const MAX_HP         := 5

@export var patrol_min: float = 80.0
@export var patrol_max: float = 250.0

# ── State ────────────────────────────────────────────────────
var hp: int = MAX_HP
var _state := "idle"
var _healed := false
var _a_cooldown := 0.0
var _b_cooldown := 2.0
var _wave_hit_dealt := false
var _wave_active := false
var _spawn_x: float = 0.0
var _wander_dir: int = 1
var _wander_dist_remaining: float = 0.0
var _wander_idle_timer: float = 0.0
var _attack_b_hit_dealt := false

func _ready() -> void:
	if GameState.boss_defeated:
		queue_free()
		return
	_spawn_x = position.x
	$Wave.visible = false
	_wave_part1.disabled = true
	_wave_part1_1.disabled = true
	_wave_part1_2.disabled = true
	_set_wave_shapes(-1)
	_big_hitbox.monitoring = false
	anim.play("idle")

func _process(delta: float) -> void:
	if _state in ["dead", "hurt", "attack_b"]:
		return

	_b_cooldown = max(0.0, _b_cooldown - delta)

	var player := get_tree().get_first_node_in_group("player")
	var player_visible := player != null and (GameState.is_nox or GameState.is_frog)

	if player_visible:
		var dist := global_position.distance_to(player.global_position)
		anim.flip_h = player.global_position.x < global_position.x
		if _b_cooldown <= 0.0 and GameState.library_intro_done:
			_attack_b()
		elif dist <= AGGRO_RANGE:
			if _state != "move":
				_state = "move"
				_set_hurtbox_shape("move")
				anim.play("move")
			position.x += sign(player.global_position.x - global_position.x) * MOVE_SPEED * delta
		else:
			_do_wander(delta)
	else:
		_do_wander(delta)
		if _b_cooldown <= 0.0 and GameState.library_intro_done:
			_attack_b()

# ── Wander ───────────────────────────────────────────────────
func _do_wander(delta: float) -> void:
	if _wander_idle_timer > 0.0:
		_wander_idle_timer -= delta
		if _state != "idle":
			_state = "idle"
			_set_hurtbox_shape("idle")
			anim.play("idle")
		return

	if _wander_dist_remaining <= 0.0:
		_wander_dir *= -1
		_wander_dist_remaining = randf_range(patrol_min, patrol_max)
		_wander_idle_timer = randf_range(0.5, 1.5)
		return

	anim.flip_h = _wander_dir < 0
	if _state != "move":
		_state = "move"
		_set_hurtbox_shape("move")
		anim.play("move")
	var step := MOVE_SPEED * delta
	position.x += _wander_dir * step
	_wander_dist_remaining -= step

# ── Attacks ──────────────────────────────────────────────────
func _attack_a() -> void:
	_state = "attack_a"
	_set_hurtbox_shape("attack_a")
	_a_cooldown = 1.8
	_b_cooldown = max(_b_cooldown, 1.0)
	_set_wave_shapes(-1)
	$Wave.visible = false
	anim.play("attack_a")
	_run_wave_sequence()
	await anim.animation_finished
	if _state == "dead":
		return
	_state = "idle"
	_set_hurtbox_shape("idle")
	anim.play("idle")

func _player_in_shapes(frame_prefix: String) -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return false
	var player_pos := player.global_position
	for child in _big_hitbox.get_children():
		if not (child is CollisionShape2D):
			continue
		var cs := child as CollisionShape2D
		if not cs.name.begins_with(frame_prefix):
			continue
		var local_pos: Vector2 = cs.global_transform.affine_inverse() * player_pos
		var shape := cs.shape
		if shape is RectangleShape2D:
			var ext := (shape as RectangleShape2D).size * 0.5
			if abs(local_pos.x) <= ext.x and abs(local_pos.y) <= ext.y:
				return true
		elif shape is CircleShape2D:
			if local_pos.length() <= (shape as CircleShape2D).radius:
				return true
		elif shape is CapsuleShape2D:
			var cap := shape as CapsuleShape2D
			var half_h := cap.height * 0.5 - cap.radius
			var nearest_y: float = clamp(local_pos.y, -half_h, half_h)
			if Vector2(local_pos.x, local_pos.y - nearest_y).length() <= cap.radius:
				return true
	return false

func _attack_b_try_hit(frame_prefix: String) -> void:
	if _attack_b_hit_dealt:
		return
	if not (GameState.is_nox or GameState.is_frog):
		return
	_big_hitbox.scale.x = -1.0 if anim.flip_h else 1.0
	if not _player_in_shapes(frame_prefix):
		return
	_attack_b_hit_dealt = true
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return
	var dir: float = sign(player.global_position.x - global_position.x)
	create_tween().tween_property(player, "global_position:x",
		player.global_position.x + dir * KNOCKBACK_B, 0.2)
	player.take_damage(GameState.max_hp)

func _attack_b() -> void:
	_state = "attack_b"
	_set_hurtbox_shape("attack_b")
	_b_cooldown = 3.5
	_attack_b_hit_dealt = false

	var frame_conn := func():
		if anim.frame == 7:
			_screen_shake()
			SFX.play("boss_attack", -1.9)
			_attack_b_try_hit("Frame7")
		elif anim.frame == 8:
			_attack_b_try_hit("Frame8")

	anim.frame_changed.connect(frame_conn)
	anim.play("attack_b")
	await anim.animation_finished

	if anim.frame_changed.is_connected(frame_conn):
		anim.frame_changed.disconnect(frame_conn)

	if _state == "dead":
		return
	_state = "idle"
	_set_hurtbox_shape("idle")
	anim.play("idle")

# ── Wave sequence ────────────────────────────────────────────
func _run_wave_sequence() -> void:
	while anim.frame < 4 and _state == "attack_a":
		await anim.frame_changed
	if _state != "attack_a":
		return
	# Travel phase — Wave node stays static, only sprite moves
	# $Wave.scale.x is kept in sync with anim.flip_h in _process
	_wave_active = true
	_wave_hit_dealt = false
	$Wave.visible = true
	wave_anim.position.x = 77.0
	wave_anim.play("wave-attack")
	_wave_part1.disabled = true
	_wave_part1_1.disabled = true
	_wave_part1_2.disabled = true
	_set_wave_shapes(-1)
	# Sprite travels visually; shapes activate as it passes through each zone
	var tw := create_tween().set_parallel(true)
	tw.tween_property(wave_anim, "position:x", 117.0, WAVE_TRAVEL_DURATION)
	tw.tween_callback(func(): _wave_part1.disabled = false)
	tw.tween_callback(func(): _wave_part1_1.disabled = false).set_delay(WAVE_TRAVEL_DURATION * 0.4)
	tw.tween_callback(func(): _wave_part1_2.disabled = false).set_delay(WAVE_TRAVEL_DURATION * 0.8)
	await tw.finished
	if _state == "dead":
		_cleanup_wave()
		return
	# Splash phase
	_wave_hit_dealt = false
	_wave_part1.disabled = true
	_wave_part1_1.disabled = true
	_wave_part1_2.disabled = true
	_set_wave_shapes(0)
	wave_anim.frame_changed.connect(_on_wave_end_frame_changed)
	wave_anim.play("wave-end")
	await wave_anim.animation_finished
	wave_anim.frame_changed.disconnect(_on_wave_end_frame_changed)
	_cleanup_wave()

func _on_wave_end_frame_changed() -> void:
	_set_wave_shapes(wave_anim.frame)

func _cleanup_wave() -> void:
	_wave_part1.disabled = true
	_wave_part1_1.disabled = true
	_wave_part1_2.disabled = true
	_set_wave_shapes(-1)
	$Wave.visible = false
	_wave_active = false
	_a_cooldown = 5.0

# ── Wave helpers ─────────────────────────────────────────────
func _set_wave_shapes(frame: int) -> void:
	_wave_part2.disabled = not (frame >= 0 and frame < 3)
	_wave_part3.disabled = not (frame >= 3 and frame < 6)
	_wave_part4.disabled = not (frame >= 6)

func _on_wave_body_entered(body: Node2D) -> void:
	if _wave_hit_dealt or _state == "dead":
		return
	if body.is_in_group("player"):
		_wave_hit_dealt = true
		var dir: float = sign(body.global_position.x - global_position.x)
		create_tween().tween_property(body, "global_position:x",
			body.global_position.x + dir * KNOCKBACK_A, 0.2)
		body.take_damage(GameState.max_hp)

# ── Heal (once) ──────────────────────────────────────────────
func _heal() -> void:
	_healed = true
	_state = "heal"
	_set_hurtbox_shape("heal")
	anim.play("healing")
	await anim.animation_finished
	if _state == "dead":
		return
	hp = min(hp + 1, MAX_HP)
	_state = "idle"
	_set_hurtbox_shape("idle")
	anim.play("idle")

# ── Damage ───────────────────────────────────────────────────
func _screen_shake(duration: float = 0.3, strength: float = 8.0) -> void:
	var camera := get_viewport().get_camera_2d()
	if not camera:
		return
	var tw := create_tween()
	var steps := 6
	for i in steps:
		var s := strength * (1.0 - float(i) / steps)
		tw.tween_property(camera, "offset", Vector2(randf_range(-s, s), randf_range(-s, s)), duration / steps)
	tw.tween_property(camera, "offset", Vector2.ZERO, 0.05)

func _on_hurtbox_area_entered(_area: Area2D) -> void:
	pass

func _hurt() -> void:
	_state = "hurt"
	_set_hurtbox_shape("hurt")
	hurtbox.set_deferred("monitoring", false)
	var tw := create_tween()
	tw.tween_property(anim, "modulate", Color(4.0, 4.0, 4.0), 0.05)
	tw.tween_property(anim, "modulate", Color(1.0, 1.0, 1.0), 0.12)
	await tw.finished
	await get_tree().create_timer(0.18).timeout
	hurtbox.set_deferred("monitoring", true)
	if _state == "dead":
		return
	_state = "idle"
	_set_hurtbox_shape("idle")
	anim.play("idle")

func _die() -> void:
	_state = "dead"
	hurtbox.set_deferred("monitoring", false)
	GameState.boss_defeated = true
	var tw := create_tween()
	tw.tween_property(anim, "modulate", Color(4.0, 4.0, 4.0), 0.08)
	tw.tween_property(anim, "modulate", Color(1.0, 1.0, 1.0), 0.08)
	tw.tween_property(anim, "modulate", Color(4.0, 4.0, 4.0), 0.08)
	tw.tween_property(anim, "modulate", Color(1.0, 1.0, 1.0), 0.08)
	tw.tween_property(anim, "modulate:a", 0.0, 0.6)
	await tw.finished
	queue_free()
