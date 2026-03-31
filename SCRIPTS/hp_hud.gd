extends CanvasLayer

@onready var heart: AnimatedSprite2D = $Container/Heart0
@onready var holder: AnimatedSprite2D = $Container/Holder0

var _prev_hp: int = -1
var _blink_timer: float = 0.0
var _display_alpha: float = 0.0
var _alpha_target: float = 0.0

const FADE_SPEED := 3.0

func _ready() -> void:
	holder.play("Idle")
	_blink_timer = _next_blink_time()
	holder.animation_finished.connect(_on_holder_animation_finished)
	_display_alpha = 1.0 if (GameState.is_nox or GameState.is_frog) else 0.0
	_alpha_target = _display_alpha

func show_dead() -> void:
	heart.play("Dead-HP")

func refresh() -> void:
	_prev_hp = -1

func fade_in() -> void:
	if _display_alpha < 0.5:
		_display_alpha = 1.0
		heart.visible = false
		holder.play("Entrance")
	_alpha_target = 1.0

func fade_out() -> void:
	_alpha_target = 0.0

func _process(delta: float) -> void:
	_display_alpha = move_toward(_display_alpha, _alpha_target, delta * FADE_SPEED)
	visible = GameState.has_sword and _display_alpha > 0.01
	if visible:
		$Container.modulate.a = _display_alpha * (1.0 - SceneTransitions.color_rect.modulate.a)

	if GameState.player_hp != _prev_hp:
		_prev_hp = GameState.player_hp
		if GameState.player_hp <= 0:
			heart.play("Dead-HP")
		else:
			match GameState.player_hp:
				5: heart.play("5_5-HP")
				4: heart.play("4_5-HP")
				3: heart.play("3_5-HP")
				2: heart.play("2_5-HP")
				1: heart.play("1_5-HP")

	if holder.animation == &"Idle":
		_blink_timer -= delta
		if _blink_timer <= 0.0:
			holder.play("Blink")

func _on_holder_animation_finished() -> void:
	if holder.animation == &"Entrance":
		heart.visible = true
		holder.play("Idle")
		_blink_timer = _next_blink_time()
	elif holder.animation == &"Blink":
		holder.play("Idle")
		_blink_timer = _next_blink_time()

func _next_blink_time() -> float:
	return randf_range(30.0, 45.0)
