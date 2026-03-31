extends Node

const NO_LOOP_TRACKS := ["death", "pause_intro"]

const TRACKS: Dictionary = {
	"main_menu":      "res://MUSIC/ADS OST-StartMenu.wav",
	"tutorial_pre":   "res://MUSIC/ADS OST-Tutorial-PreAssistant.wav",
	"tutorial_post":  "res://MUSIC/ADS OST-Tutorial-PostAssistant.wav",
	"village_broken": "res://MUSIC/ADS OST-VillageBroken.wav",
	"village_almost": "res://MUSIC/ADS OST-VillageAlmostFixed.wav",
	"village_fixed":  "res://MUSIC/ADS OST-VillageFixed.wav",
	"village_conga":  "res://MUSIC/ADS OST-VillageConga(permanant).wav",
	"home_credits":   "res://MUSIC/ADS OST-EldersHome-Credits.wav",
	"pause":          "res://MUSIC/ADS OST-PauseTheme(final).wav",
	"pause_intro":    "res://MUSIC/ADS OST-PauseTheme (intro).wav",
	"library":        "res://MUSIC/ADS OST-Library.wav",
	"death":          "res://MUSIC/ADS OST-DEATH.wav",
}

@onready var _players: Array = [$Layer0, $Layer1]
var _current_keys: Array = ["", ""]
var _tweens: Array = [null, null]
var _pitch_tweens: Array = [null, null]
var _saved_positions: Array = [-1.0, -1.0]
var _saved_keys: Array = ["", ""]
var _paused_volumes: Array = [0.0, 0.0]
var _pause_player: AudioStreamPlayer = null
var _pause_loop_stream = null
var _pause_tween = null
var _death_player: AudioStreamPlayer = null
var _death_tween = null
var _death_playing := false
var _cache: Dictionary = {}

func _load_stream(key: String) -> AudioStream:
	var stream = _cache.get(key, null)
	if stream == null:
		stream = load(TRACKS[key])
	return stream

func cache_tracks(keys: Array) -> void:
	for key in keys:
		if TRACKS.has(key) and not _cache.has(key):
			_cache[key] = _load_stream(key)

func _ready() -> void:
	_pause_player = AudioStreamPlayer.new()
	add_child(_pause_player)
	_death_player = AudioStreamPlayer.new()
	add_child(_death_player)
	var bus_idx := AudioServer.get_bus_count()
	AudioServer.add_bus()
	AudioServer.set_bus_name(bus_idx, "DeathBus")
	AudioServer.set_bus_send(bus_idx, "Master")
	var lpf := AudioEffectLowPassFilter.new()
	lpf.cutoff_hz = 800.0
	AudioServer.add_bus_effect(bus_idx, lpf)
	_death_player.bus = "DeathBus"
	for i in 2:
		var layer := i
		var p: AudioStreamPlayer = _players[i]
		p.finished.connect(func():
			if _current_keys[layer] != "" and _current_keys[layer] not in NO_LOOP_TRACKS:
				p.play()
		)

# Internal: interpolates in linear amplitude space for a perceptually smooth fade.
func _fade_linear(layer: int, target_db: float, duration: float) -> void:
	if _tweens[layer]:
		_tweens[layer].kill()
	var p: AudioStreamPlayer = _players[layer]
	var start_linear := db_to_linear(p.volume_db)
	var target_linear := db_to_linear(target_db)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tweens[layer] = tween
	tween.tween_method(
		func(v: float): p.volume_db = linear_to_db(v),
		start_linear, target_linear, duration
	)

# Start two layers in guaranteed sync.
# If BOTH have valid saved positions for the requested keys, resumes both
# (1.5s fade-in). Otherwise starts both fresh from 0. Saved state always cleared.
func start_synced_pair(key0: String, key1: String) -> void:
	if not TRACKS.has(key0) or not TRACKS.has(key1):
		push_warning("MusicPlayer: unknown track in start_synced_pair")
		return
	var stream0 = _load_stream(key0)
	var stream1 = _load_stream(key1)
	if stream0 == null or stream1 == null:
		push_error("MusicPlayer: failed to load tracks for start_synced_pair")
		return

	# Decide atomically — both must be valid or neither resumes.
	var pos0: float = _saved_positions[0] if _saved_keys[0] == key0 and _saved_positions[0] >= 0.0 else -1.0
	var pos1: float = _saved_positions[1] if _saved_keys[1] == key1 and _saved_positions[1] >= 0.0 else -1.0
	var should_resume := pos0 >= 0.0 and pos1 >= 0.0

	# Always consume full saved state.
	_saved_positions = [-1.0, -1.0]
	_saved_keys = ["", ""]
	for i in 2:
		if _tweens[i]:
			_tweens[i].kill()
			_tweens[i] = null
	_current_keys[0] = key0
	_current_keys[1] = key1

	var p0: AudioStreamPlayer = _players[0]
	var p1: AudioStreamPlayer = _players[1]
	p0.stream = stream0
	p1.stream = stream1
	p0.pitch_scale = 1.0
	p1.pitch_scale = 1.0

	if should_resume:
		p0.volume_db = -80.0
		p1.volume_db = -80.0
		p0.play(pos0)
		p1.play(pos1)
		_fade_linear(0, 0.0, 1.5)
		_fade_linear(1, 0.0, 1.5)
	else:
		p0.volume_db = 0.0
		p1.volume_db = 0.0
		p0.play()
		p1.play()

# Play a track on a layer. volume_db=0.0 is full volume; use -80.0 for silent.
func set_track(layer: int, key: String, volume_db: float = 0.0) -> void:
	if not TRACKS.has(key):
		push_warning("MusicPlayer: unknown track '%s'" % key)
		return
	var stream = _load_stream(key)
	if stream == null:
		push_error("MusicPlayer: failed to load '%s'" % TRACKS[key])
		return
	if _tweens[layer]:
		_tweens[layer].kill()
		_tweens[layer] = null
	_current_keys[layer] = key
	var p: AudioStreamPlayer = _players[layer]
	p.stream = stream
	p.pitch_scale = 1.0
	var resume_pos: float = _saved_positions[layer] if _saved_keys[layer] == key else -1.0
	_saved_positions[layer] = -1.0
	_saved_keys[layer] = ""
	if resume_pos >= 0.0:
		p.volume_db = -80.0
		p.play(resume_pos)
		_fade_linear(layer, volume_db, 1.5)
	else:
		p.volume_db = volume_db
		p.play()

# Fade a layer's volume to target_db over duration seconds.
func fade_to(layer: int, target_db: float, duration: float) -> void:
	_fade_linear(layer, target_db, duration)

# Crossfade a layer to a new track: fade out, swap stream, fade in.
func crossfade(layer: int, key: String, duration: float = 1.0) -> void:
	if not TRACKS.has(key):
		push_warning("MusicPlayer: unknown track '%s'" % key)
		return
	var p: AudioStreamPlayer = _players[layer]
	var start_db := p.volume_db
	_fade_linear(layer, -80.0, duration * 0.5)
	await _tweens[layer].finished
	var stream = _load_stream(key)
	if stream == null:
		push_error("MusicPlayer: failed to load '%s'" % TRACKS[key])
		return
	_current_keys[layer] = key
	p.stream = stream
	p.volume_db = -80.0
	p.play()
	_fade_linear(layer, start_db, duration * 0.5)

# Fade out both layers over duration seconds then stop, or cut immediately.
# target_pitch: if > 0, also tweens pitch_scale to that value over duration.
func stop_all(duration: float = 1.0, target_pitch: float = -1.0) -> void:
	for i in 2:
		var p: AudioStreamPlayer = _players[i]
		if p.playing and _current_keys[i] != "":
			_saved_positions[i] = p.get_playback_position()
			_saved_keys[i] = _current_keys[i]
		if _tweens[i]:
			_tweens[i].kill()
			_tweens[i] = null
		if duration <= 0.0:
			p.stop()
			p.volume_db = 0.0
		elif p.playing:
			_fade_linear(i, -80.0, duration)
			_tweens[i].tween_callback(p.stop)
		if target_pitch > 0.0 and duration > 0.0:
			if _pitch_tweens[i]:
				_pitch_tweens[i].kill()
			var tw := create_tween()
			tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			_pitch_tweens[i] = tw
			tw.tween_property(p, "pitch_scale", target_pitch, duration)
	_current_keys = ["", ""]

# Fade scene music out over duration, saving position for resume_music().
func fade_out_music(duration: float) -> void:
	for i in 2:
		var p: AudioStreamPlayer = _players[i]
		if _tweens[i]:
			_tweens[i].kill()
			_tweens[i] = null
		if _pitch_tweens[i]:
			_pitch_tweens[i].kill()
			_pitch_tweens[i] = null
		if p.playing and _current_keys[i] != "":
			_paused_volumes[i] = p.volume_db
			_saved_positions[i] = p.get_playback_position()
			_saved_keys[i] = _current_keys[i]
			_fade_linear(i, -80.0, duration)
			_tweens[i].tween_callback(p.stop)
	_current_keys = ["", ""]

# Cut music instantly, saving position so resume_music() can continue from here.
func pause_music() -> void:
	for i in 2:
		var p: AudioStreamPlayer = _players[i]
		if _tweens[i]:
			_tweens[i].kill()
			_tweens[i] = null
		if _pitch_tweens[i]:
			_pitch_tweens[i].kill()
			_pitch_tweens[i] = null
		if p.playing and _current_keys[i] != "":
			_paused_volumes[i] = p.volume_db
			_saved_positions[i] = p.get_playback_position()
			_saved_keys[i] = _current_keys[i]
			p.stop()

# Play pause intro at full volume; loops into pause theme immediately on finish.
# Returns track length in seconds.
func play_pause_audio() -> float:
	var intro_stream = _load_stream("pause_intro")
	if intro_stream == null:
		return 0.0
	_pause_loop_stream = _load_stream("pause")
	_pause_player.stream = intro_stream
	_pause_player.volume_db = 0.0
	_pause_player.pitch_scale = 1.0
	_pause_player.play()
	return intro_stream.get_length()

# Switch to the looping pause theme immediately — call once the visual sequence is done.
func start_pause_theme() -> void:
	if _pause_loop_stream == null:
		_pause_loop_stream = _load_stream("pause")
	if _pause_loop_stream == null:
		return
	_pause_player.stream = _pause_loop_stream
	_pause_player.volume_db = linear_to_db(0.15)
	_pause_player.pitch_scale = 1.0
	_pause_player.play()

# Fade the pause theme out over duration — call when the closing animation starts.
func fade_out_pause(duration: float) -> void:
	if not _pause_player or not _pause_player.playing:
		return
	if _pause_tween:
		_pause_tween.kill()
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_pause_tween = tw
	tw.tween_method(
		func(v: float): _pause_player.volume_db = linear_to_db(v),
		db_to_linear(_pause_player.volume_db), db_to_linear(-80.0), duration
	)
	tw.tween_callback(_pause_player.stop)

# Fade scene music back in over fade_duration. Call after fade_out_pause().
func resume_music(fade_duration: float = 0.0) -> void:
	for i in 2:
		if _saved_keys[i] == "" or not TRACKS.has(_saved_keys[i]):
			continue
		var stream = _load_stream(_saved_keys[i])
		if stream == null:
			_saved_keys[i] = ""
			continue
		var p: AudioStreamPlayer = _players[i]
		var pos: float = _saved_positions[i]
		_current_keys[i] = _saved_keys[i]
		_saved_positions[i] = -1.0
		_saved_keys[i] = ""
		p.stream = stream
		p.pitch_scale = 1.0
		if fade_duration > 0.0:
			p.volume_db = -80.0
			if pos >= 0.0:
				p.play(pos)
			else:
				p.play()
			_fade_linear(i, _paused_volumes[i], fade_duration)
		else:
			p.volume_db = _paused_volumes[i]
			if pos >= 0.0:
				p.play(pos)
			else:
				p.play()

const DEATH_MAX_DB := -12.0  # ~25% linear volume

func play_death_audio() -> void:
	_death_playing = true
	var stream = load(TRACKS["death"])
	if stream == null:
		return
	_death_player.stream = stream
	await get_tree().create_timer(2.5).timeout
	if not _death_playing:
		return
	_death_loop()

func _death_loop(start_pos: float = 0.0) -> void:
	if not _death_playing:
		return
	var length: float = _death_player.stream.get_length()
	var fade_in_dur := length * 0.25
	var fade_out_dur := length * 0.25

	_death_player.volume_db = -80.0
	_death_player.play(start_pos)
	_fade_death(DEATH_MAX_DB, fade_in_dur)

	var remaining := length - start_pos
	var wait_before_fadeout := maxf(remaining - fade_out_dur, fade_in_dur)
	await get_tree().create_timer(wait_before_fadeout).timeout
	if not _death_playing:
		return

	_fade_death(-80.0, fade_out_dur)
	await get_tree().create_timer(fade_out_dur).timeout

	_death_loop(randf_range(1.0, 2.0))

func _fade_death(target_db: float, duration: float) -> void:
	if _death_tween:
		_death_tween.kill()
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_death_tween = tw
	tw.tween_method(
		func(v: float): _death_player.volume_db = linear_to_db(v),
		db_to_linear(_death_player.volume_db), db_to_linear(target_db), duration
	)

func stop_death_audio() -> void:
	_death_playing = false
	if _death_tween:
		_death_tween.kill()
		_death_tween = null
	_death_player.stop()
