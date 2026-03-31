extends CanvasLayer

@onready var _sprite: AnimatedSprite2D = $Anchor/GemSprite

var _prev_count: int = -1

func _ready() -> void:
	visible = false

func show_hud() -> void:
	visible = true
	_update_frame()

func _process(_delta: float) -> void:
	if not visible:
		return
	var count := GameState.gems_collected.size()
	if count != _prev_count:
		_prev_count = count
		_update_frame()

func _update_frame() -> void:
	_sprite.frame = clampi(GameState.gems_collected.size(), 0, 4)
