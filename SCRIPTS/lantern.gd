extends PointLight2D

@export var base_energy: float = 1.1
@export var flicker_amplitude: float = 0.12
## Phase offset so multiple lanterns don't flicker in sync.
@export var phase_offset: float = 0.0

const _FREQ_A: float = 1.7   # primary breathing
const _FREQ_B: float = 2.93  # secondary flutter
const _FREQ_C: float = 0.41  # slow swell

var _time: float = 0.0

func _ready() -> void:
	energy = base_energy
	_time = phase_offset

func _process(delta: float) -> void:
	_time += delta
	var wave := (
		sin(_time * _FREQ_A * TAU) * 0.5 +
		sin(_time * _FREQ_B * TAU) * 0.35 +
		sin(_time * _FREQ_C * TAU) * 0.15
	)
	energy = base_energy + wave * (flicker_amplitude * 0.5)
