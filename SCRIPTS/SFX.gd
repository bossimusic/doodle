extends Node

const SOUNDS: Dictionary = {
	"jump":             "res://ALL SFX DOODLE/PLAYER SFX/Player-Jump_(SFX).wav",
	"land":             "res://ALL SFX DOODLE/PLAYER SFX/Player-Landing_(SFX)wav.wav",
	"land_hard":        "res://ALL SFX DOODLE/PLAYER SFX/First-Fall_TH(SFX).wav",
	"footstep_grass":   "res://ALL SFX DOODLE/PLAYER SFX/Footstep-Grass_(SFX).wav",
	"footstep_1":       "res://ALL SFX DOODLE/PLAYER SFX/Footstep-Other1_(SFX).wav",
	"footstep_2":       "res://ALL SFX DOODLE/PLAYER SFX/Footstep-Other2_(SFX).wav",
	"slide":            "res://ALL SFX DOODLE/Player-Dash_(SFX).wav",
	"dash":             "res://ALL SFX DOODLE/Player-Dash_(SFX).wav",
	"attack_1":         "res://ALL SFX DOODLE/PLAYER SFX/Player-Sword-Swing_(SFX).wav",
	"attack_2":         "res://ALL SFX DOODLE/PLAYER SFX/Player-Sword-Swing_(SFX).wav",
	"hurt":             "res://ALL SFX DOODLE/Player_Hurt_(SFX).wav",
	"checkpoint":       "res://ALL SFX DOODLE/P-Checkpoint-Lighting_(SFX).wav",
	"enemy_hit":        "res://ALL SFX DOODLE/Skeleton-Hit_(SFX).wav",
	"pickup_gem":       "res://ALL SFX DOODLE/MISC SFX/Gem-Pickup_(SFX)wav.wav",
	"boss_attack":      "res://ALL SFX DOODLE/MISC SFX/Golem-Attack.wav",
	"assistant_error":  "res://ALL SFX DOODLE/NPC SFX/Assistant-Error_TH(SFX).wav",
	"library_transfer": "res://ALL SFX DOODLE/NPC SFX/Assistant-Transfer_(SFX).wav",
	"ui_confirm":       "res://ALL SFX DOODLE/UI SFX/UI-Confirm_(SFX).wav",
	"ui_select":        "res://ALL SFX DOODLE/UI SFX/UI-Hover:Select_(SFX)wav.wav",
	"dialogue_open":    "res://ALL SFX DOODLE/UI-Paper_Dialogue-Box_openclose(SFX).wav",
	"dialogue_advance": "res://ALL SFX DOODLE/UI-Continue-Skip_(SFX.wav",
	"glitch":           "res://ALL SFX DOODLE/Glitch_Transition(SFX).mp3",
}

var _footstep_toggle := false
var enabled := true
var _next_land_sound: String = ""
var _next_land_volume: float = 0.0
var force_alternate_footsteps := false

func play(key: String, volume_db: float = 0.0) -> void:
	if not enabled:
		return
	var resolved_key := key
	var resolved_volume := volume_db
	if key == "land" and _next_land_sound != "":
		resolved_key = _next_land_sound
		resolved_volume = _next_land_volume
		_next_land_sound = ""
		_next_land_volume = 0.0
	if not SOUNDS.has(resolved_key):
		return
	if not FileAccess.file_exists(SOUNDS[resolved_key]):
		return
	var player := AudioStreamPlayer.new()
	add_child(player)
	player.stream = load(SOUNDS[resolved_key])
	player.volume_db = resolved_volume
	player.play()
	player.finished.connect(player.queue_free)

func play_tracked(key: String, volume_db: float = 0.0) -> AudioStreamPlayer:
	if not enabled or not SOUNDS.has(key) or not FileAccess.file_exists(SOUNDS[key]):
		return null
	var player := AudioStreamPlayer.new()
	add_child(player)
	player.stream = load(SOUNDS[key])
	player.volume_db = volume_db
	player.play()
	return player

func play_footstep(on_grass: bool = true) -> void:
	if on_grass:
		play("footstep_grass", -14.0)
	else:
		_footstep_toggle = !_footstep_toggle
		play("footstep_1" if _footstep_toggle else "footstep_2", -14.0)
