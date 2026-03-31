extends CharacterBody2D

# ─── CONSTANTS ─────────────────────────────────────────────
const WALK_SPEED       := 100.0
const SPRINT_SPEED     := 175.0
const JUMP_VELOCITY    := -400.0
const FROG_WALK_SPEED  := 50.0
const FROG_JUMP_VELOCITY := -600.0

# Slide (Nox)
const SLIDE_SPEED := 250.0
const SLIDE_TIME  := 0.35

# Wall movement (Nox)
const WALL_JUMP_VELOCITY    := Vector2(160.0, -420.0)
const WALL_SLIDE_GRAV_SCALE := 0.25

const DROP_THROUGH_TIME := 0.2

# ─── NODES ────────────────────────────────────────────────
@onready var animated_sprite_2d: AnimatedSprite2D = $DoodleSprite
@onready var _nox_sprite:        AnimatedSprite2D = $NoxSprite
@onready var _frog_sprite:       AnimatedSprite2D = $FrogSprite
@onready var floor_ray: RayCast2D = $FloorRay
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var attack_hitbox_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D
@onready var _transform_effect: AnimatedSprite2D = $TransformEffect
@onready var _camera: Camera2D = $Camera2D


# ─── STATE ────────────────────────────────────────────────
const COYOTE_TIME := 0.15
var coyote_timer    := 0.0
var current_speed: float = WALK_SPEED
var is_jumping      := false
var _fall_loop_timer: float = 0.0
var is_restarting   := false

# Slide / Dash
var is_sliding  := false
var slide_dir   := 0.0
var slide_timer := 0.0
var is_dashing  := false
var dash_dir    := 0.0
var dash_timer  := 0.0
var _has_dashed := false

# Wall
var is_wall_sliding   := false
var _is_wall_jumping  := false


# Attack
enum AttackState { NONE, ATTACK1, ATTACK2, ATTACK1_END }
var attack_state     := AttackState.NONE
var _attack_buffer_timer := 0.0

# Damage
var _invincible_timer: float = 0.0
var _is_dying := false
var _hurt_anim_active := false

# ─── FOOTSTEP FRAME CONFIG ──────────────────────────────
# Change these frame indices to shift when footstep sounds fire
const WALK_STEP_FRAMES := [2, 6]   # frames in WALK / NOX_WALK anim
const RUN_STEP_FRAMES  := [2, 6]   # frames in RUN / NOX_RUN anim
const FROG_STEP_FRAMES := [2]      # frames in FROG_WALK anim

# Screen shake
var _shake_timer: float = 0.0
var _shake_strength: float = 0.0

# Transform animation
var _is_transforming := false
var _pending_nox := false
var _pending_frog := false


# ─── HELPERS ──────────────────────────────────────────────
func _anim(key: String) -> String:
	if GameState.is_frog:
		return "FROG_" + key
	return ("NOX_" + key) if GameState.is_nox else key

func _current_sprite() -> AnimatedSprite2D:
	if GameState.is_frog: return _frog_sprite
	if GameState.is_nox:  return _nox_sprite
	return animated_sprite_2d

# Animations that only exist for Nox (no Doodle/Frog equivalent)
const NOX_ONLY_ANIMS := ["ATTACK_1", "ATTACK_1_END", "ATTACK_2",
	"SLIDE", "DASH", "WALL_SLIDE", "WALL_JUMP", "WALL_JUMP-2", "HURT", "DEATH"]

# Play an action key on Doodle+Nox sprites simultaneously (Frog only when active).
# Nox-only keys only update NoxSprite.
func _play_all(key: String) -> void:
	if key in NOX_ONLY_ANIMS:
		_nox_sprite.play("NOX_" + key)
		return
	animated_sprite_2d.play(key)
	_nox_sprite.play("NOX_" + key)
	if GameState.is_frog:
		_frog_sprite.play("FROG_" + key)

# Set flip_h on all form sprites simultaneously
func _set_flip(h: bool) -> void:
	animated_sprite_2d.flip_h = h
	_nox_sprite.flip_h = h
	_frog_sprite.flip_h = h


# ─── INIT ─────────────────────────────────────────────────
func _ready() -> void:
	attack_hitbox_shape.disabled = true
	# Connect animation_finished and frame_changed for all three sprites via code
	animated_sprite_2d.animation_finished.connect(_on_anim_finished.bind(animated_sprite_2d))
	_nox_sprite.animation_finished.connect(_on_anim_finished.bind(_nox_sprite))
	_frog_sprite.animation_finished.connect(_on_anim_finished.bind(_frog_sprite))
	animated_sprite_2d.frame_changed.connect(func(): _on_frame_changed(animated_sprite_2d))
	_nox_sprite.frame_changed.connect(func(): _on_frame_changed(_nox_sprite))
	_frog_sprite.frame_changed.connect(func(): _on_frame_changed(_frog_sprite))
	# Set initial visibility to match current GameState (e.g. after scene reload as Nox)
	animated_sprite_2d.visible = not GameState.is_nox and not GameState.is_frog
	_nox_sprite.visible  = GameState.is_nox
	_frog_sprite.visible = GameState.is_frog
	if GameState.arriving_via_teleport:
		var marker = get_tree().get_first_node_in_group("teleport_spawn")
		if marker:
			global_position = marker.global_position
		GameState.arriving_via_teleport = false
	elif GameState.arriving_from_home:
		var marker = get_tree().get_first_node_in_group("home_door_spawn")
		if marker:
			global_position = marker.global_position
		GameState.arriving_from_home = false
	elif GameState.arriving_from_library:
		var marker = get_tree().get_first_node_in_group("library_door_spawn")
		if marker:
			global_position = marker.global_position
		GameState.arriving_from_library = false
	elif GameState.spawn_position != Vector2.ZERO:
		global_position = GameState.spawn_position
		GameState.spawn_position = Vector2.ZERO
	# Anchor checkpoint_position to this scene on fresh entry.
	# Prevents cross-scene coordinates from a previous scene being used as spawn.
	if not GameState.respawned_from_death:
		GameState.checkpoint_position = global_position
	GameState.respawned_from_death = false


# ─── PHYSICS ──────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	# Screen shake (runs even during death animation)
	if _shake_timer > 0.0:
		_shake_timer -= delta
		_camera.offset = Vector2(
			randf_range(-_shake_strength, _shake_strength),
			randf_range(-_shake_strength, _shake_strength)
		)
	else:
		_camera.offset = Vector2.ZERO

	if _is_dying:
		return

	# Iframes
	if _invincible_timer > 0.0:
		_invincible_timer -= delta

	# Gravity
	if not is_on_floor() and not is_dashing:
		velocity += get_gravity() * delta


	# Detect falling (walked off ledge) — delay JUMP_LOOP by a few frames
	if not is_on_floor() and not is_jumping and not is_dashing:
		_fall_loop_timer += delta
		if _fall_loop_timer >= 0.09:
			is_jumping = true
			_fall_loop_timer = 0.0
			_play_all("JUMP_LOOP")
	else:
		_fall_loop_timer = 0.0

	# Coyote time
	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer -= delta

	# ─── TRANSFORM (1/2/3 keys + D-pad) ────────────────────
	if GameState.has_sword and is_on_floor() and not _is_transforming:
		if Input.is_action_just_pressed("transform_doodle"):
			_start_transform(false, false)
		elif Input.is_action_just_pressed("transform_nox"):
			_start_transform(true, false)
		elif Input.is_action_just_pressed("transform_frog") and GameState.has_frog_form:
			_start_transform(false, true)

	# ─── DROP THROUGH (Doodle / Nox) ───────────────────────
	if Input.is_action_just_pressed("ui_down") and is_on_floor() \
			and not Input.is_action_just_pressed("transform_nox"):
		if floor_ray.is_colliding():
			var collider = floor_ray.get_collider()
			if collider and collider.is_in_group("oneway_platform"):
				drop_through_platform()

	# ─── JUMP ──────────────────────────────────────────────
	var can_jump := coyote_timer > 0.0 and not is_wall_sliding \
			and attack_state == AttackState.NONE
	var blocked_by_interact := GameState.player_in_interact_zone \
			and Input.is_action_just_pressed("interact")
	if Input.is_action_just_pressed("jump") and can_jump and not blocked_by_interact:
		velocity.y = FROG_JUMP_VELOCITY if GameState.is_frog else JUMP_VELOCITY
		coyote_timer = 0.0
		is_jumping = true
		SFX.play("jump", -13.0)
		_play_all("JUMP_START")

	# ─── NOX: GROUND SLIDE ─────────────────────────────────
	if GameState.is_nox and GameState.has_dash and not is_sliding and is_on_floor() \
			and Input.is_action_just_pressed("slide"):
		var dir := Input.get_axis("move_left", "move_right")
		if dir != 0:
			is_sliding  = true
			slide_dir   = dir
			slide_timer = SLIDE_TIME
			_nox_sprite.play("NOX_SLIDE")
			SFX.play("slide", 6.0)

	if is_sliding:
		slide_timer -= delta
		velocity.x = slide_dir * SLIDE_SPEED
		if slide_timer <= 0 or not is_on_floor():
			is_sliding = false

	# ─── NOX: AIR DASH ─────────────────────────────────────
	if GameState.is_nox and GameState.has_dash and not is_dashing and not _has_dashed and not is_on_floor() \
			and not is_wall_sliding and Input.is_action_just_pressed("slide"):
		var dir := Input.get_axis("move_left", "move_right")
		if dir != 0:
			is_dashing  = true
			_has_dashed = true
			dash_dir    = dir
			dash_timer  = SLIDE_TIME
			_nox_sprite.play("NOX_DASH")
			SFX.play("dash", 6.0)

	if is_dashing:
		dash_timer -= delta
		velocity.x = dash_dir * SLIDE_SPEED
		velocity.y = 0.0
		if dash_timer <= 0 or is_on_floor():
			is_dashing = false

	# ─── NOX: WALL SLIDE + WALL JUMP ───────────────────────
	var was_wall_sliding := is_wall_sliding
	is_wall_sliding = false
	if GameState.is_nox and is_on_wall() and not is_on_floor() \
			and velocity.y > 0 and not is_sliding and _wall_has_4_tiles():
		is_wall_sliding = true
		velocity.y = min(velocity.y, 60.0)
		velocity.y += get_gravity().y * delta * WALL_SLIDE_GRAV_SCALE
		_nox_sprite.play("NOX_WALL_SLIDE")

	if was_wall_sliding and not is_wall_sliding and not is_on_floor():
		_play_all("JUMP_LOOP")

	if is_wall_sliding and Input.is_action_just_pressed("jump"):
		var wall_normal := get_wall_normal()
		var dir := Input.get_axis("move_left", "move_right")
		velocity.x = wall_normal.x * WALL_JUMP_VELOCITY.x
		velocity.y = WALL_JUMP_VELOCITY.y
		is_wall_sliding = false
		is_jumping = true
		_is_wall_jumping = true
		var pressing_into_wall := dir != 0 and (dir < 0.0) != (wall_normal.x < 0.0)
		if pressing_into_wall:
			_set_flip(dir < 0)
			_nox_sprite.play("NOX_WALL_JUMP-2")
		else:
			_set_flip(wall_normal.x < 0)
			_nox_sprite.play("NOX_WALL_JUMP")

	# ─── NOX: ATTACK COMBO ─────────────────────────────────
	var _started_attack1 := false
	if GameState.is_nox and attack_state == AttackState.NONE \
			and is_on_floor() and Input.is_action_just_pressed("attack"):
		_start_attack1()
		_started_attack1 = true

	if attack_state == AttackState.ATTACK1 and not _started_attack1 \
			and Input.is_action_just_pressed("attack"):
		_attack_buffer_timer = 0.25

	if attack_state == AttackState.ATTACK1:
		_attack_buffer_timer = max(0.0, _attack_buffer_timer - delta)

	# Keep hitbox in front of player
	attack_hitbox.position.x = -53.0 if _current_sprite().flip_h else 53.0

	# ─── HORIZONTAL MOVEMENT ───────────────────────────────
	var direction := Input.get_axis("move_left", "move_right")

	if GameState.is_frog:
		current_speed = FROG_WALK_SPEED
	elif Input.is_action_pressed("sprint"):
		current_speed = SPRINT_SPEED
	else:
		current_speed = WALK_SPEED

	if not is_sliding and not is_dashing and attack_state == AttackState.NONE:
		if direction != 0:
			velocity.x = direction * current_speed
		else:
			velocity.x = move_toward(velocity.x, 0, current_speed)
	elif attack_state != AttackState.NONE:
		velocity.x = move_toward(velocity.x, 0, current_speed)

	# Flip all sprites (suppressed during wall jump to preserve facing direction)
	if not _is_wall_jumping:
		if direction > 0:
			_set_flip(false)
		elif direction < 0:
			_set_flip(true)

	# Wall slide overrides flip to face away from wall
	if is_wall_sliding:
		_set_flip(get_wall_normal().x < 0)

	move_and_slide()

	# Landing reset (post-move_and_slide so is_on_floor() is current)
	if is_on_floor() and is_jumping:
		is_jumping = false
		SFX.play("land", -13.0)
	if is_on_floor():
		_has_dashed = false

	# ─── GROUND ANIMATIONS ─────────────────────────────────
	# Runs after move_and_slide so landing frame is handled immediately
	if is_on_floor() and not is_jumping \
			and not is_wall_sliding and not is_sliding \
			and attack_state == AttackState.NONE \
			and not _hurt_anim_active:
		if abs(velocity.x) > 0:
			if Input.is_action_pressed("sprint") and not GameState.is_frog:
				_play_all("RUN")
			else:
				_play_all("WALK")
		else:
			_play_all("IDLE")

	# Restart input (safe + deferred)
	if Input.is_action_just_pressed("restart") and not is_restarting and not GameState.is_transitioning:
		is_restarting = true
		restart_scene()


# ─── FORM TOGGLE ──────────────────────────────────────────
func _start_transform(to_nox: bool, to_frog: bool) -> void:
	if to_nox or to_frog:
		HP_HUD.fade_in()
	else:
		HP_HUD.fade_out()
	_is_transforming = true
	_pending_nox = to_nox
	_pending_frog = to_frog
	_transform_effect.flip_h = _current_sprite().flip_h
	_transform_effect.position.y = -9.0 if GameState.is_frog else -18.0
	_transform_effect.visible = true
	_transform_effect.play("Frog Transform" if to_frog else "Transform")

func _on_transform_animation_finished() -> void:
	_transform_effect.visible = false
	_is_transforming = false
	GameState.is_nox = _pending_nox
	GameState.is_frog = _pending_frog
	_apply_form()

func _apply_form() -> void:
	is_sliding = false
	is_dashing = false
	_has_dashed = false
	is_wall_sliding = false
	_is_wall_jumping = false
	attack_state = AttackState.NONE
	attack_hitbox_shape.disabled = true
	_attack_buffer_timer = 0.0
	# Show only the active form's sprite
	animated_sprite_2d.visible = not GameState.is_nox and not GameState.is_frog
	_nox_sprite.visible  = GameState.is_nox
	_frog_sprite.visible = GameState.is_frog
	# Frog doesn't play in background, so seed its animation on switch
	if GameState.is_frog:
		_frog_sprite.play("FROG_IDLE")

func set_frog_form(enabled: bool) -> void:
	GameState.is_frog = enabled
	if enabled:
		GameState.is_nox = false
	_apply_form()

func set_nox_form(enabled: bool) -> void:
	GameState.is_nox = enabled
	if enabled:
		GameState.is_frog = false
	_apply_form()


# ─── WALL HELPERS ─────────────────────────────────────────
func _wall_has_4_tiles() -> bool:
	var space := get_world_2d().direct_space_state
	var wall_dir := -get_wall_normal().x
	for y_off in [-22.5, -7.5, 7.5, 22.5]:
		var from := global_position + Vector2(0, y_off)
		var to := from + Vector2(wall_dir * 20.0, 0)
		var query := PhysicsRayQueryParameters2D.create(from, to)
		query.exclude = [self]
		var result := space.intersect_ray(query)
		if not result:
			return false
		if (result.collider as Node).is_in_group("no_wall_slide"):
			return false
	return true


# ─── ATTACK HELPERS ────────────────────────────────────────
func _start_attack1() -> void:
	attack_state = AttackState.ATTACK1
	attack_hitbox_shape.disabled = false
	_nox_sprite.play("NOX_ATTACK_1")
	SFX.play("attack_1", -7.3)

func _start_attack2() -> void:
	attack_state = AttackState.ATTACK2
	_nox_sprite.play("NOX_ATTACK_2")
	SFX.play("attack_2", -7.3)

func _start_attack1_end() -> void:
	attack_state = AttackState.ATTACK1_END
	attack_hitbox_shape.disabled = true
	_nox_sprite.play("NOX_ATTACK_1_END")


# ─── DROP THROUGH PLATFORMS ───────────────────────────────
func drop_through_platform() -> void:
	set_collision_mask_value(1, false)
	await get_tree().create_timer(DROP_THROUGH_TIME).timeout
	set_collision_mask_value(1, true)


# ─── SAFE SCENE RESTART ───────────────────────────────────
func restart_scene(from_death: bool = false) -> void:
	call_deferred("_do_restart_scene", from_death)

func _do_restart_scene(from_death: bool = false) -> void:
	GameState.is_transitioning = true
	await SceneTransitions.fade_out(0.25)
	GameState.reset()
	if GameState.checkpoint_position != Vector2.ZERO:
		GameState.spawn_position = GameState.checkpoint_position
	if from_death:
		GameState.respawned_from_death = true
	get_tree().reload_current_scene()


# ─── SCREEN SHAKE ─────────────────────────────────────────
func shake(duration: float = 0.25, strength: float = 8.0) -> void:
	_shake_timer = duration
	_shake_strength = strength


# ─── DAMAGE ───────────────────────────────────────────────
func take_damage(amount: int) -> void:
	if _invincible_timer > 0.0 or _is_dying:
		return
	GameState.player_hp -= amount
	_invincible_timer = 0.5
	var cs := _current_sprite()
	var tween = create_tween()
	tween.tween_property(cs, "modulate", Color(4, 0.3, 0.3), 0.05)
	tween.tween_property(cs, "modulate", Color(1, 1, 1), 0.2)
	if GameState.player_hp <= 0:
		HP_HUD.show_dead()
		_is_dying = true
		SFX.play("hurt", -7.3)
		if GameState.is_nox:
			_nox_sprite.play("NOX_DEATH")
		else:
			DeadScreen.show_dead()
	else:
		shake(0.25, 5.0)
	if GameState.is_nox and GameState.player_hp > 0:
		_hurt_anim_active = true
		_nox_sprite.play("NOX_HURT")
		SFX.play("hurt", -7.3)


# ─── ANIMATION CALLBACKS ──────────────────────────────────
func _get_on_grass() -> bool:
	if SFX.force_alternate_footsteps:
		return false
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		if col and col.get_collider() and col.get_collider().is_in_group("alternate_footsteps"):
			return false
	return true

func _on_frame_changed(sprite: AnimatedSprite2D) -> void:
	if sprite != _current_sprite():
		return
	var frame := sprite.frame
	match sprite.animation:
		"WALK", "NOX_WALK":
			if frame in WALK_STEP_FRAMES:
				SFX.play_footstep(_get_on_grass())
		"RUN", "NOX_RUN":
			if frame in RUN_STEP_FRAMES:
				SFX.play_footstep(_get_on_grass())
		"FROG_WALK":
			if frame in FROG_STEP_FRAMES:
				SFX.play_footstep(_get_on_grass())

func _on_anim_finished(sprite: AnimatedSprite2D) -> void:
	if sprite != _current_sprite():
		return
	var anim := sprite.animation.trim_prefix("NOX_").trim_prefix("FROG_")
	match anim:
		"JUMP_START", "WALL_JUMP", "WALL_JUMP-2":
			_is_wall_jumping = false
			if not is_on_floor():
				_play_all("JUMP_LOOP")
		"ATTACK_1":
			if _attack_buffer_timer > 0.0:
				_attack_buffer_timer = 0.0
				_start_attack2()
			else:
				_start_attack1_end()
		"ATTACK_2", "ATTACK_1_END":
			attack_state = AttackState.NONE
			attack_hitbox_shape.disabled = true
			_attack_buffer_timer = 0.0
			_play_all("IDLE")
		"DASH":
			if not is_on_floor():
				_play_all("JUMP_LOOP")
		"HURT":
			_hurt_anim_active = false
			_nox_sprite.play("NOX_IDLE")
		"DEATH":
			DeadScreen.show_dead()
