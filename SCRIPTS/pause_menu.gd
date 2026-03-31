extends CanvasLayer

@onready var bg: ColorRect = $BG
@onready var gear_outline: AnimatedSprite2D = $GearOutline
@onready var gear_selected: AnimatedSprite2D = $GearSelected
@onready var spellbook: AnimatedSprite2D = $SpellbookSprite
@onready var page_turn: AnimatedSprite2D = $PageTurnSprite
@onready var book_content: Control = $BookContent
@onready var paused_label: Label = $BookContent/PausedLabel
@onready var continue_label: Label = $BookContent/ContinueLabel
@onready var leave_label: Label = $BookContent/LeaveLabel
@onready var controls_button: Label = $BookContent/ControlsButton
@onready var controls_label: RichTextLabel = $BookContent/ControlsLabel
@onready var controls_label2: RichTextLabel = $BookContent/ControlsLabel2
@onready var back_label: Label = $BookContent/BackLabel
@onready var _y_btn_back: Sprite2D = $BookContent/YBtnBack
@onready var _esc_labels: Array[Label] = [$EscLabel, $EscLabel2, $EscLabel3, $EscLabel4, $EscLabel5, $EscLabel6, $EscLabel7, $EscLabel8]
@onready var _y_btns: Array[Sprite2D] = [$BookContent/YBtn0, $BookContent/YBtn1, $BookContent/YBtn2]

var _paused := false
var _animating := false
var _text_typed := false
var _selected := 0
var _nav_cooldown := 0.0
var _controls_open := false
var _last_left_selected := 0
var _continue_full_right := 0.0
var _leave_full_right := 0.0
var _controls_btn_full_right := 0.0
var _book_rest_y: float
var _book_rest_scale: Vector2
var _leaving := false

const ANIM_DURATION := 8.0 / 12.0
const COLOR_SELECTED := Color(1.0, 1.0, 0.3)
const COLOR_NORMAL := Color(1.0, 1.0, 1.0)
const BOOK_ABOVE_Y := -1200.0
const SLIDE_DURATION := 0.4
const INTRO_START_Y := 1950.0
const INTRO_START_SCALE := Vector2(0.75, 0.75)
const INTRO_FADE_WAIT := 1.0
const INTRO_SHAKE_BASE := 15.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_book_rest_y = spellbook.position.y
	_book_rest_scale = spellbook.scale
	gear_selected.visible = false
	spellbook.visible = false
	bg.visible = false
	book_content.visible = false
	# Store full widths then set clip mode for left-to-right reveal
	_continue_full_right = continue_label.offset_right
	_leave_full_right = leave_label.offset_right
	_controls_btn_full_right = controls_button.offset_right
	continue_label.clip_text = true
	leave_label.clip_text = true
	controls_button.clip_text = true
	paused_label.visible_ratio = 0.0
	continue_label.offset_right = continue_label.offset_left
	leave_label.offset_right = leave_label.offset_left
	controls_button.offset_right = controls_button.offset_left
	gear_outline.play("spin")
	gear_selected.play("spin_selected")
	spellbook.animation_finished.connect(_on_spellbook_animation_finished)
	_update_selection()
	for lbl in _esc_labels:
		lbl.visible = false
	GameState.input_scheme_changed.connect(func(_c): _update_esc_label())
	_update_esc_label()
	GameState.input_scheme_changed.connect(func(_c): _update_controls_text())
	_update_controls_text()

func _update_esc_label() -> void:
	var show_esc := GameState.assistant_dialogue_done and not _paused and not _animating and not GameState.is_using_controller and not GameState.is_in_dialogue
	for lbl in _esc_labels:
		lbl.visible = show_esc

func _process(delta: float) -> void:
	if _nav_cooldown > 0:
		_nav_cooldown -= delta
	if not _paused:
		var should_show := GameState.assistant_dialogue_done and not GameState.is_in_dialogue
		if gear_outline.visible != should_show:
			gear_outline.visible = should_show
	_update_esc_label()

func _update_selection() -> void:
	continue_label.add_theme_color_override("font_color", COLOR_SELECTED if _selected == 0 else COLOR_NORMAL)
	leave_label.add_theme_color_override("font_color", COLOR_SELECTED if _selected == 1 else COLOR_NORMAL)
	controls_button.add_theme_color_override("font_color", COLOR_SELECTED if _selected == 2 else COLOR_NORMAL)
	back_label.add_theme_color_override("font_color", COLOR_SELECTED if _selected == 2 else COLOR_NORMAL)
	for i in _y_btns.size():
		_y_btns[i].visible = _text_typed and (i == _selected) and not _controls_open
	_y_btn_back.visible = _text_typed and (_selected == 2) and _controls_open

func _reset_text_offsets() -> void:
	paused_label.visible_ratio = 0.0
	continue_label.offset_right = continue_label.offset_left
	leave_label.offset_right = leave_label.offset_left
	controls_button.offset_right = controls_button.offset_left

func toggle() -> void:
	if _animating:
		return
	_animating = true
	_paused = !_paused

	gear_outline.visible = false
	gear_selected.visible = true

	if _paused:
		get_tree().paused = true
		_text_typed = false
		_selected = 0
		_controls_open = false
		controls_label.visible = false
		controls_label2.visible = false
		back_label.visible = false
		_reset_label_modulates()
		_update_selection()
		_update_controls_text()
		gear_outline.pause()
		gear_selected.pause()
		book_content.modulate.a = 0.0
		book_content.visible = true
		if not GameState.pause_intro_shown:
			await _play_pause_intro()
		else:
			Music.fade_out_music(SLIDE_DURATION)
			bg.modulate.a = 0.0
			spellbook.modulate.a = 1.0
			spellbook.position.y = BOOK_ABOVE_Y
			spellbook.scale = _book_rest_scale
			spellbook.animation = &"opening"
			spellbook.frame = 0
			bg.visible = true
			spellbook.visible = true
			var tw := create_tween()
			tw.set_parallel(true)
			tw.tween_property(spellbook, "position:y", _book_rest_y, SLIDE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(bg, "modulate:a", 1.0, SLIDE_DURATION)
			await tw.finished
		spellbook.play("opening")
		Music.start_pause_theme()
	else:
		# Keep tree paused until closing animation finishes so input can't leak to game
		_leaving = false
		gear_outline.play("spin")
		gear_selected.play("spin_selected")
		_reset_text_offsets()
		_reset_label_modulates()
		_controls_open = false
		controls_label.visible = false
		controls_label2.visible = false
		spellbook.play("closing")
		Music.fade_out_pause(ANIM_DURATION)
		# slide-out happens in _on_spellbook_animation_finished

	await get_tree().create_timer(0.15).timeout
	gear_selected.visible = false
	gear_outline.visible = true

func _on_spellbook_animation_finished() -> void:
	if spellbook.animation == &"opening":
		spellbook.pause()
		_animating = false
		_type_in_text()
	elif spellbook.animation == &"closing":
		if _leaving:
			return  # _leave() handles its own cleanup
		# Slide out + fade bg while book slides up
		var tw := create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.set_parallel(true)
		tw.tween_property(spellbook, "position:y", BOOK_ABOVE_Y, SLIDE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(bg, "modulate:a", 0.0, SLIDE_DURATION)
		tw.tween_property(book_content, "modulate:a", 0.0, SLIDE_DURATION)
		await tw.finished
		spellbook.visible = false
		bg.visible = false
		book_content.visible = false
		spellbook.position.y = _book_rest_y
		spellbook.scale = _book_rest_scale
		Music.resume_music(SLIDE_DURATION)
		get_tree().paused = false
		_animating = false

func _shake(intensity: float) -> void:
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for i in 8:
		tw.tween_property(self, "offset",
			Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * intensity, 0.03)
	tw.tween_property(self, "offset", Vector2.ZERO, 0.03)

func _play_pause_intro() -> void:
	GameState.pause_intro_shown = true
	Music.fade_out_music(INTRO_FADE_WAIT)
	# Fade in background
	bg.modulate.a = 0.0
	bg.visible = true
	var bg_tw := create_tween()
	bg_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	bg_tw.tween_property(bg, "modulate:a", 1.0, INTRO_FADE_WAIT)
	# Book appears small at bottom and slides up
	spellbook.position.y = INTRO_START_Y
	spellbook.scale = INTRO_START_SCALE
	spellbook.animation = &"opening"
	spellbook.frame = 0
	spellbook.modulate.a = 1.0
	spellbook.visible = true
	var slide_tw := create_tween()
	slide_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	slide_tw.tween_property(spellbook, "position:y", _book_rest_y, INTRO_FADE_WAIT).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await slide_tw.finished
	var T: float = Music.play_pause_audio()
	var eighteenth := T / 18.0
	# Hit 1 at T/18
	await get_tree().create_timer(eighteenth, true).timeout
	_shake(INTRO_SHAKE_BASE * 0.5)
	var tw1 := create_tween()
	tw1.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw1.tween_property(spellbook, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw1.finished
	# Hit 2 at T/9
	await get_tree().create_timer(eighteenth - 0.15, true).timeout
	_shake(INTRO_SHAKE_BASE)
	var tw2 := create_tween()
	tw2.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw2.tween_property(spellbook, "scale", Vector2(1.25, 1.25), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw2.finished
	# Hit 3 at T/6
	await get_tree().create_timer(eighteenth - 0.15, true).timeout
	_shake(INTRO_SHAKE_BASE * 1.5)
	var tw3 := create_tween()
	tw3.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw3.tween_property(spellbook, "scale", Vector2(1.5, 1.5), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw3.finished
	# Hit 4 at T/4 (midpoint between T/6 and T/3)
	await get_tree().create_timer(T / 12.0 - 0.15, true).timeout
	_shake(INTRO_SHAKE_BASE * 2.0)
	var tw4 := create_tween()
	tw4.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw4.tween_property(spellbook, "scale", _book_rest_scale, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw4.finished

func _type_in_text() -> void:
	book_content.modulate.a = 1.0
	_reset_text_offsets()
	var tw := create_tween()
	tw.tween_property(paused_label, "visible_ratio", 1.0, 0.4)
	tw.tween_interval(0.5)
	tw.tween_property(continue_label, "offset_right", _continue_full_right, 0.4)
	tw.parallel().tween_property(leave_label, "offset_right", _leave_full_right, 0.4)
	tw.parallel().tween_property(controls_button, "offset_right", _controls_btn_full_right, 0.4)
	tw.tween_callback(func(): _text_typed = true; _update_selection())

func _leave() -> void:
	_animating = true
	_leaving = true
	get_tree().paused = false
	_reset_text_offsets()
	_reset_label_modulates()
	_controls_open = false
	controls_label.visible = false
	controls_label2.visible = false
	back_label.visible = false
	gear_outline.play("spin")
	gear_selected.play("spin_selected")
	spellbook.play("closing")
	var tw := create_tween()
	tw.tween_property(spellbook, "modulate:a", 0.0, ANIM_DURATION)
	tw.parallel().tween_property(book_content, "modulate:a", 0.0, ANIM_DURATION)
	await spellbook.animation_finished
	bg.visible = false
	spellbook.visible = false
	book_content.visible = false
	spellbook.position.y = _book_rest_y
	spellbook.scale = _book_rest_scale
	_leaving = false
	_paused = false
	_animating = false
	GoodbyeScreen.show_goodbye()

func _fade_left_page(alpha: float, duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(paused_label, "modulate:a", alpha, duration)
	tw.parallel().tween_property(continue_label, "modulate:a", alpha, duration)
	tw.parallel().tween_property(leave_label, "modulate:a", alpha, duration)
	tw.parallel().tween_property(controls_button, "modulate:a", alpha, duration)
	await tw.finished

func _reset_label_modulates() -> void:
	paused_label.modulate.a = 1.0
	continue_label.modulate.a = 1.0
	leave_label.modulate.a = 1.0
	controls_button.modulate.a = 1.0
	controls_label.modulate.a = 1.0
	controls_label2.modulate.a = 1.0
	back_label.modulate.a = 1.0

func _go_to_controls() -> void:
	_animating = true
	_text_typed = false
	_update_selection()
	# Fade out left page text
	await _fade_left_page(0.0, 0.3)
	# Page turn
	page_turn.visible = true
	page_turn.play("default")
	await page_turn.animation_finished
	page_turn.visible = false
	# Pop in controls content
	_controls_open = true
	_update_controls_text()
	controls_label.modulate.a = 0.0
	controls_label.visible = true
	controls_label2.modulate.a = 0.0
	controls_label2.visible = true
	back_label.modulate.a = 0.0
	back_label.visible = true
	var tw := create_tween()
	tw.tween_property(controls_label, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(controls_label2, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(back_label, "modulate:a", 1.0, 0.25)
	await tw.finished
	_animating = false
	_text_typed = true
	_update_selection()

func _go_from_controls() -> void:
	_animating = true
	_text_typed = false
	_update_selection()
	# Fade out controls content
	var tw := create_tween()
	tw.tween_property(controls_label, "modulate:a", 0.0, 0.25)
	tw.parallel().tween_property(controls_label2, "modulate:a", 0.0, 0.25)
	tw.parallel().tween_property(back_label, "modulate:a", 0.0, 0.25)
	await tw.finished
	controls_label.visible = false
	controls_label2.visible = false
	back_label.visible = false
	_controls_open = false
	_selected = _last_left_selected
	# Page turn
	page_turn.visible = true
	page_turn.play("default")
	await page_turn.animation_finished
	page_turn.visible = false
	# Fade in left page text
	await _fade_left_page(1.0, 0.3)
	_animating = false
	_text_typed = true
	_update_selection()

func _confirm() -> void:
	SFX.play("ui_confirm", -10.5)
	if _selected == 0:
		toggle()
	elif _selected == 1:
		_leave()
	elif _selected == 2:
		if not _controls_open:
			_go_to_controls()
		else:
			_go_from_controls()

func _input(event: InputEvent) -> void:
	if not _paused:
		# Toggle open
		if GameState.is_transitioning or GameState.is_in_dialogue or DeadScreen.visible:
			return
		if not GameState.assistant_dialogue_done:
			return
		if not get_tree().get_first_node_in_group("player"):
			return
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				toggle()
				get_viewport().set_input_as_handled()
		elif event is InputEventJoypadButton and event.pressed:
			if event.button_index == JOY_BUTTON_START:
				toggle()
				get_viewport().set_input_as_handled()
	else:
		# Menu navigation — only when fully open
		if _animating:
			return
		if event.is_action_pressed("move_right") and _selected < 2:
			_last_left_selected = _selected
			_selected = 2
			_nav_cooldown = 0.25
			SFX.play("ui_select", -10.5)
			_update_selection()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("move_left") and _selected == 2 and not _controls_open:
			_selected = _last_left_selected
			_nav_cooldown = 0.25
			SFX.play("ui_select", -10.5)
			_update_selection()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or event.is_action_pressed("jump"):
			if _selected == 2:
				get_viewport().set_input_as_handled()
				return
			if _nav_cooldown > 0:
				get_viewport().set_input_as_handled()
				return
			var going_up := event.is_action_pressed("ui_up") or event.is_action_pressed("jump")
			if going_up:
				_selected = max(0, _selected - 1)
			else:
				_selected = min(1, _selected + 1)
			_nav_cooldown = 0.25
			SFX.play("ui_select", -10.5)
			_update_selection()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("interact"):
			get_viewport().set_input_as_handled()
			_confirm()
		elif event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				_selected = 0
				_confirm()
		elif event is InputEventJoypadButton and event.pressed:
			if event.button_index == JOY_BUTTON_START:
				get_viewport().set_input_as_handled()
				_selected = 0
				_confirm()

const _ICON_PATH := "res://ASSETS/Controller interface/Controller-"

func _icon(file: String) -> String:
	return "[img=62x70]" + _ICON_PATH + file + "[/img]"

func _locked(label: String) -> String:
	return "?".repeat(label.length())

func _update_controls_text() -> void:
	var c := GameState.is_using_controller
	var sw := GameState.has_sword
	var fr := GameState.has_frog_form

	var s := "[font_size=65]"
	var e := "[/font_size]"

	var t1 := ""
	t1 += "MOVEMENT\n"
	t1 += s + "  Walk: " + (_icon("Joystick-static.png") if c else "A / D") + "\n"
	t1 += "  Jump: " + (_icon("AButton.png") if c else "Space") + "\n"
	t1 += "  Sprint: " + (_icon("XButton.png") if c else "Shift") + "\n"
	if sw:
		t1 += "  Slide/Dash: " + (_icon("Left-Bumper.png") if c else "C") + "\n"
		t1 += "  Wall Jump: " + (_icon("AButton.png") + " (slide)" if c else "Space (sliding)") + e + "\n"
	else:
		t1 += "  " + _locked("Slide/Dash") + ": ?\n"
		t1 += "  " + _locked("Wall Jump") + ": ?" + e + "\n"
	t1 += "\n"
	t1 += "FORMS\n"
	if sw:
		t1 += s + "  Doodle: " + (_icon("Controller-DPAD-UP.png") if c else "1") + "\n"
		t1 += "  Nox: " + (_icon("Controller-DPAD-DOWN.png") if c else "2") + "\n"
		if fr:
			t1 += "  Frog: " + (_icon("Controller-DPAD-LEFT.png") + " / " + _icon("Controller-DPAD-RIGHT.png") if c else "3") + e + "\n"
		else:
			t1 += "  " + _locked("Frog") + ": ?" + e + "\n"
	else:
		t1 += s + "  " + _locked("Doodle") + ": ?\n"
		t1 += "  " + _locked("Nox") + ": ?\n"
		t1 += "  " + _locked("Frog") + ": ?" + e + "\n"
	controls_label.text = t1

	var t2 := ""
	t2 += "COMBAT\n"
	if sw:
		t2 += s + "  Attack: " + (_icon("Right-Bumper.png") if c else "J") + e + "\n"
	else:
		t2 += s + "  " + _locked("Attack") + ": ?" + e + "\n"
	t2 += "\n"
	t2 += "MISC\n"
	t2 += s + "  Interact: " + (_icon("YButton.png.png") if c else "E") + "\n"
	t2 += "  Pause: " + ("Options" if c else "ESC") + e + "\n"
	controls_label2.text = t2
