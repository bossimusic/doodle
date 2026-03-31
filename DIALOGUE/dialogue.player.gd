extends CanvasLayer

@export_file("*.json") var d_file

signal dialogue_finished

const CHARS_PER_SECOND := 40.0

const CONTROLLER_TO_KB := {
	"DPAD-DOWN": "2",
	"DPAD-UP": "1",
	"DPAD-LEFT": "3",
	"DPAD-RIGHT": "3",
	"Left-Bumper": "C",
	"Right-Bumper": "J",
	"Joystick-static": "←/→",
	"AButton": "Space",
	"YButton": "E",
	"XButton": "Shift",
	"BButton": "Enter",
}

func _adapt_text(text: String) -> String:
	if GameState.is_using_controller:
		return text.replace("[OPTIONS]", "Options")
	text = text.replace("[OPTIONS]", "ESC")
	var regex := RegEx.new()
	regex.compile("\\[img=105x118\\][^\\[]*Controller-([^.]+)\\.png[^\\[]*\\[/img\\]")
	var result := text
	var used_values := {}
	for m in regex.search_all(text):
		var key := m.get_string(1)
		for kb_key in CONTROLLER_TO_KB:
			if key.contains(kb_key):
				var replacement: String = CONTROLLER_TO_KB[kb_key]
				if replacement in used_values:
					result = result.replace(m.get_string(), "")
				else:
					result = result.replace(m.get_string(), replacement)
					used_values[replacement] = true
				break
	return result

const PORTRAITS := {
	"Nox": preload("res://ASSETS/NPC'S/Portraits/Dead-Nox.png"),
	"Nox?": preload("res://ASSETS/NPC'S/Portraits/Doodle-Nox.png"),
	"Village Elder": preload("res://ASSETS/NPC'S/Portraits/Village Elder.png"),
}

@onready var _portrait: TextureRect = $Portrait
@onready var _text_label: RichTextLabel = $NinePatchRect/TextLabel
@onready var _name_label: Label = $NinePatchRect/NameLabel

const TEXT_LEFT_WITH_PORTRAIT := 566.0
const TEXT_LEFT_NO_PORTRAIT := 100.0

var _image_rect: TextureRect
var _prompt_ctrl: TextureRect
var _prompt_kb: TextureRect

var dialogue = []
var current_dialogue_id = 0
var d_active = false
var _just_finished := false
var _full_text := ""
var _displayed_chars := 0.0
var _typing := false

func _ready():
	$NinePatchRect.visible = false
	_image_rect = TextureRect.new()
	_image_rect.anchors_preset = 15
	_image_rect.anchor_right = 1.0
	_image_rect.anchor_bottom = 1.0
	_image_rect.offset_left = _text_label.offset_left
	_image_rect.offset_top = _text_label.offset_top
	_image_rect.offset_right = _text_label.offset_right
	_image_rect.offset_bottom = _text_label.offset_bottom
	_image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image_rect.visible = false
	$NinePatchRect.add_child(_image_rect)

	_prompt_ctrl = TextureRect.new()
	_prompt_ctrl.texture = preload("res://ASSETS/Controller interface/Controller-YButton.png.png")
	_prompt_ctrl.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_prompt_ctrl.offset_left = 3220.0
	_prompt_ctrl.offset_top = 405.0
	_prompt_ctrl.offset_right = 3340.0
	_prompt_ctrl.offset_bottom = 525.0
	_prompt_ctrl.visible = false
	$NinePatchRect.add_child(_prompt_ctrl)

	_prompt_kb = TextureRect.new()
	_prompt_kb.texture = preload("res://ASSETS/MISC/E-kaycap.png")
	_prompt_kb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_prompt_kb.offset_left = 3220.0
	_prompt_kb.offset_top = 405.0
	_prompt_kb.offset_right = 3340.0
	_prompt_kb.offset_bottom = 525.0
	_prompt_kb.visible = false
	$NinePatchRect.add_child(_prompt_kb)

	GameState.input_scheme_changed.connect(func(_c): _update_advance_prompt())

func _update_advance_prompt() -> void:
	var visible_prompt: bool = d_active
	_prompt_ctrl.visible = visible_prompt and GameState.is_using_controller
	_prompt_kb.visible = visible_prompt and not GameState.is_using_controller

var _suppress_open_sound := false

func start():
	if d_active or _just_finished:
		return
	GameState.is_in_dialogue = true
	$NinePatchRect.visible = true
	if not _suppress_open_sound:
		SFX.play("dialogue_open", -2.5)
	_suppress_open_sound = false
	d_active = true
	dialogue = load_dialogue()
	current_dialogue_id = -1
	next_script()

func load_dialogue():
	if d_file == null or d_file.is_empty():
		push_error("dialogue: d_file not set")
		return []
	var file = FileAccess.open(d_file, FileAccess.READ)
	return JSON.parse_string(file.get_as_text())

func _input(event):
	if not d_active:
		return
	if event.is_action_pressed("advance_dialogue"):
		SFX.play("dialogue_advance", -1.9)
		if _typing:
			_skip_typewriter()
		else:
			next_script()
	elif event.is_action_pressed("skip_dialogue"):
		end_dialogue()

func next_script():
	current_dialogue_id += 1
	if current_dialogue_id >= len(dialogue):
		end_dialogue()
		return
	var entry: Dictionary = dialogue[current_dialogue_id]
	var speaker: String = entry['NAME']
	$NinePatchRect/NameLabel.text = speaker
	var portrait_tex = PORTRAITS.get(speaker, null)
	_portrait.texture = portrait_tex
	_portrait.visible = portrait_tex != null
	var text_left := TEXT_LEFT_WITH_PORTRAIT if portrait_tex != null else TEXT_LEFT_NO_PORTRAIT
	_name_label.offset_left = text_left
	_text_label.offset_left = text_left
	var image_path: String = entry.get("IMAGE", "")
	if image_path != "":
		_image_rect.texture = load(image_path)
		_image_rect.visible = true
		_text_label.visible = false
		var text: String = entry.get("TEXT", "")
		if text != "":
			_start_typewriter(text)
		else:
			_typing = false
			_text_label.text = ""
			_update_advance_prompt()
	else:
		_image_rect.visible = false
		_text_label.visible = true
		_start_typewriter(entry['TEXT'])

func _start_typewriter(text: String) -> void:
	text = _adapt_text(text)
	_full_text = text
	_displayed_chars = 0.0
	_typing = true
	_update_advance_prompt()
	$NinePatchRect/TextLabel.text = text
	$NinePatchRect/TextLabel.visible_characters = 0

func _process(_delta: float) -> void:
	_just_finished = false
	if not _typing:
		return
	_displayed_chars += _delta * CHARS_PER_SECOND
	$NinePatchRect/TextLabel.visible_characters = int(_displayed_chars)
	if int(_displayed_chars) >= $NinePatchRect/TextLabel.get_total_character_count():
		_typing = false
		_update_advance_prompt()

func _skip_typewriter() -> void:
	_typing = false
	$NinePatchRect/TextLabel.visible_characters = -1
	_update_advance_prompt()

func start_next(file: String) -> void:
	_just_finished = false
	_suppress_open_sound = true
	d_file = file
	start()

func end_dialogue():
	d_active = false
	_just_finished = true
	_typing = false
	GameState.is_in_dialogue = false
	$NinePatchRect.visible = false
	_portrait.visible = false
	_image_rect.visible = false
	_text_label.visible = true
	_prompt_ctrl.visible = false
	_prompt_kb.visible = false
	emit_signal("dialogue_finished")
