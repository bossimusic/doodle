extends AnimatableBody2D

## Movement speed in units/second.
@export var speed: float = 60.0

## Movement direction. Use (1,0) for right, (-1,0) for left, (0,-1) for up, etc.
@export var direction: Vector2 = Vector2.RIGHT

## When true, the platform bounces back and forth over [travel] pixels.
## When false, it wraps using wrap_min / wrap_max.
@export var bounce: bool = false

## Distance in pixels to travel before reversing (bounce mode only).
@export var travel: float = 200.0

## Seconds to pause at each end before reversing (bounce mode only).
@export var pause_duration: float = 0.5

## When the platform exits past this coordinate it wraps to wrap_max, and vice versa.
## Match these to just outside your room's visible bounds.
@export var wrap_min: float = -200.0
@export var wrap_max: float = 1200.0

var _dir: Vector2
var _traveled: float = 0.0
var _pause_timer: float = 0.0

func _ready() -> void:
	_dir = direction.normalized()

func _physics_process(delta: float) -> void:
	if bounce and _pause_timer > 0.0:
		_pause_timer -= delta
		return

	var step := speed * delta
	position += _dir * step

	if bounce:
		_traveled += step
		if _traveled >= travel:
			_traveled = 0.0
			_dir = -_dir
			_pause_timer = pause_duration
	else:
		var axis := 0 if abs(direction.x) >= abs(direction.y) else 1
		if position[axis] > wrap_max:
			position[axis] = wrap_min
		elif position[axis] < wrap_min:
			position[axis] = wrap_max
