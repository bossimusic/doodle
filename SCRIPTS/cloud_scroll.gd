extends TileMapLayer

@export var speed: float = 5.0
@export var wrap_width: float = 1872.0

static var _saved_offsets: Dictionary = {}

var _origin_x: float

func _ready() -> void:
	_origin_x = position.x
	if _saved_offsets.has(name):
		position.x = _origin_x - _saved_offsets[name]

func _process(delta: float) -> void:
	position.x -= speed * delta
	if position.x <= _origin_x - wrap_width:
		position.x += wrap_width
	_saved_offsets[name] = _origin_x - position.x
