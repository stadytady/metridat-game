extends CanvasLayer
## Esc (or START): pause the world, release the mouse, adjust settings. A second
## page moves the keys, a third gives the credits and the licences of what the
## game ships. Walked with the mouse, or with the stick and A on a pad.

signal closed
## The credits page opened from the title screen was closed: back to the title.
signal credits_closed

var _root: Control
var _main: VBoxContainer
var _keys: VBoxContainer
var _credits: VBoxContainer
var _credits_scroll: ScrollContainer
var _credits_back: Button
## How fast the stick scrolls the credits (px/s).
const CREDITS_SCROLL := 900.0
var _resume: Button
var _sens_label: Label
var _sens: HSlider
var _vol_label: Label
var _vol: HSlider
var _fov_label: Label
var _fov: HSlider
var _invert: CheckBox
var _psx: CheckBox
var _motion: CheckBox
var _captions: CheckBox
var _text_label: Label
var _text: HSlider
var _lang: Array[Button] = []
## action -> its key button on the controls page.
var _key_buttons := {}
var _keys_back: Button
## The action waiting for its new key (&"" when none), and the frame a key
## press was taken for it: that Esc must not also close the menu.
var waiting: StringName = &""
var _taken_frame := -1
## Opened from the title for the credits only: back and Esc return to the title.
var _from_title := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(centre)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel())
	panel.custom_minimum_size = Vector2(760, 0)
	centre.add_child(panel)
	var pages := VBoxContainer.new()
	panel.add_child(pages)
	_main = _build_main()
	pages.add_child(_main)
	_keys = _build_keys()
	pages.add_child(_keys)
	_keys.visible = false
	_credits = _build_credits()
	pages.add_child(_credits)
	_credits.visible = false
	_root.visible = false
	Game.device_changed.connect(func() -> void:
		if _root.visible and Game.pad:
			_focus_first())
	Game.settings_changed.connect(_refresh_keys)


func _build_main() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	var title := UiStyle.label("UI_PAUSED", 40, UiStyle.BORDER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_resume = UiStyle.button("UI_RESUME")
	_resume.pressed.connect(close)
	col.add_child(_resume)
	# two columns: in one the page outgrew a 1080 screen, and the text size
	# setting makes every row taller still
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 40)
	col.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	cols.add_child(left)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 14)
	cols.add_child(right)
	_sens_label = UiStyle.label("", 24)
	left.add_child(_sens_label)
	_sens = _slider(0.1, 4.0, 0.05, _on_sens)
	left.add_child(_sens)
	_vol_label = UiStyle.label("", 24)
	left.add_child(_vol_label)
	_vol = _slider(0.0, 1.0, 0.05, _on_volume)
	left.add_child(_vol)
	_fov_label = UiStyle.label("", 24)
	left.add_child(_fov_label)
	_fov = _slider(Game.FOV_MIN, Game.FOV_MAX, 1.0, _on_fov)
	left.add_child(_fov)
	_text_label = UiStyle.label("", 24)
	left.add_child(_text_label)
	_text = _slider(Game.TEXT_MIN, Game.TEXT_MAX, 0.1, _on_text)
	left.add_child(_text)
	_invert = _check("UI_INVERT_Y", func(on: bool) -> void:
		Game.invert_y = on
		Game.save_settings())
	right.add_child(_invert)
	_psx = _check("UI_PSX", func(on: bool) -> void:
		Game.psx_effects = on
		Game.save_settings())
	right.add_child(_psx)
	_motion = _check("UI_CAMERA_MOTION", func(on: bool) -> void:
		Game.head_bob = on
		Game.save_settings())
	right.add_child(_motion)
	_captions = _check("UI_CAPTIONS", func(on: bool) -> void:
		Game.captions = on
		Game.save_settings())
	right.add_child(_captions)
	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 12)
	lang_row.add_child(UiStyle.label("UI_LANGUAGE", 24))
	var group := ButtonGroup.new()
	for code: String in Game.LANGUAGES:
		var b := UiStyle.button(code.to_upper())
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(90, 0)
		b.pressed.connect(func() -> void: Game.set_language(code))
		lang_row.add_child(b)
		_lang.append(b)
	right.add_child(lang_row)
	var controls := UiStyle.button("UI_CONTROLS")
	controls.pressed.connect(show_keys)
	col.add_child(controls)
	var credits := UiStyle.button("UI_CREDITS_LICENSES")
	credits.pressed.connect(show_credits)
	col.add_child(credits)
	# playtests: the folder of session logs (SessionLog), where there is one
	if SessionLog.supported():
		var logs := UiStyle.button("UI_OPEN_LOGS")
		logs.pressed.connect(func() -> void:
			DirAccess.make_dir_recursive_absolute(SessionLog.DIR)
			OS.shell_open(ProjectSettings.globalize_path(SessionLog.DIR)))
		col.add_child(logs)
	var quit := UiStyle.button("UI_QUIT")
	quit.pressed.connect(func() -> void:
		Game.save_requested.emit()
		get_tree().quit())
	col.add_child(quit)
	col.add_child(UiStyle.label("UI_FOOTNOTE", 18, UiStyle.MUTED))
	return col


## The controls page: a row per movable action with its key, the pad's fixed
## layout below, and a way back to the defaults.
func _build_keys() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	var title := UiStyle.label("UI_CONTROLS", 40, UiStyle.BORDER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	for entry: Array in Keys.REBIND:
		var row := HBoxContainer.new()
		var name_label := UiStyle.label(String(entry[1]), 24)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var b := UiStyle.button("")
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.custom_minimum_size = Vector2(240, 0)
		var action: StringName = entry[0]
		b.pressed.connect(func() -> void: listen(action))
		row.add_child(b)
		_key_buttons[action] = b
		col.add_child(row)
	var hint := UiStyle.label("UI_KEYS_HINT", 18, UiStyle.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(hint)
	var pad := UiStyle.label("UI_PAD_LAYOUT", 18, UiStyle.MUTED)
	pad.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(pad)
	var reset := UiStyle.button("UI_KEYS_RESET")
	reset.pressed.connect(func() -> void:
		waiting = &""
		Game.reset_keys())
	col.add_child(reset)
	_keys_back = UiStyle.button("UI_BACK")
	_keys_back.pressed.connect(show_main)
	col.add_child(_keys_back)
	_refresh_keys()
	return col


## The credits page: who made the game and with what, then the licences of
## what it ships that is not its own - Godot's (and its components', straight
## from the engine) and Dialogue Manager's. Long: it scrolls, with the wheel or
## the stick.
func _build_credits() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	var title := UiStyle.label("UI_CREDITS_LICENSES", 40, UiStyle.BORDER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_credits_scroll = ScrollContainer.new()
	_credits_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# a ScrollContainer asks for no height of its own (see the journal)
	_credits_scroll.custom_minimum_size = Vector2(1100, 620)
	col.add_child(_credits_scroll)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_credits_scroll.add_child(body)
	_credits_back = UiStyle.button("UI_BACK")
	_credits_back.pressed.connect(_credits_done)
	col.add_child(_credits_back)
	return col


## Fills the credits on first sight: the engine's licence texts run to dozens of
## labels, and building them with the menu would slow every start for a page
## most players never open.
func _fill_credits() -> void:
	var body: VBoxContainer = _credits_scroll.get_child(0)
	if body.get_child_count() > 0:
		return
	var head := func(key: String) -> void:
		var h := UiStyle.label(key, 26, UiStyle.HISTORY)
		body.add_child(h)
	var line := func(text: String, size: int, color: Color) -> void:
		var l := UiStyle.label(text, size, color)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 1060
		body.add_child(l)
	head.call("UI_CREDITS_GAME")
	for key: String in ["UI_CREDITS_1", "UI_CREDITS_AUTHOR", "UI_CREDITS_2", "UI_CREDITS_3", "UI_CREDITS_4", "UI_CREDITS_5"]:
		line.call(key, 22, UiStyle.TEXT)
	var ver := UiStyle.label(tr("UI_CREDITS_VERSION") % SessionLog.version(), 22, UiStyle.TEXT)
	ver.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	body.add_child(ver)
	head.call("UI_CREDITS_LIBS")
	line.call("UI_CREDITS_LEGAL", 18, UiStyle.MUTED)
	head.call("UI_CREDITS_ENGINE")
	_plain(line, Engine.get_license_text())
	head.call(Licenses.DIALOGUE_MANAGER_NAME)
	_plain(line, Licenses.DIALOGUE_MANAGER)
	head.call("UI_CREDITS_THIRD")
	for c: String in Licenses.godot_components():
		_plain(line, c, 16)
	var texts: Dictionary = Licenses.godot_component_licences()
	for name: String in texts:
		var h := UiStyle.label(name, 20, UiStyle.BORDER)
		h.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		body.add_child(h)
		_plain(line, texts[name], 14)
	UiStyle.rescale(body)


## A line of legal text: shown as written, never looked up as a key.
func _plain(line: Callable, text: String, size := 16) -> void:
	line.call(text, size, UiStyle.MUTED)
	var l: Label = (_credits_scroll.get_child(0) as Control).get_child(-1)
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED


func _slider(lo: float, hi: float, step: float, on_change: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size = Vector2(480, 32)
	s.value_changed.connect(on_change)
	return s


func _check(key: String, on_toggle: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = key
	UiStyle.font(c, 24)
	c.toggled.connect(on_toggle)
	return c


func _refresh_keys() -> void:
	for action: StringName in _key_buttons:
		var b: Button = _key_buttons[action]
		b.text = tr("UI_PRESS_KEY") if action == waiting else Keys.key_name(Game.key_for(action))


func _process(delta: float) -> void:
	if waiting != &"" or Engine.get_process_frames() == _taken_frame:
		return
	if _root.visible and _credits.visible:
		# the stick (or W/S) scrolls the long licence texts
		var dy := Input.get_axis(&"move_forward", &"move_back")
		if absf(dy) > 0.2:
			_credits_scroll.scroll_vertical += int(dy * CREDITS_SCROLL * delta)
	if _root.visible:
		if Input.is_action_just_pressed(&"pause") or Input.is_action_just_pressed(&"back"):
			if _credits.visible:
				_credits_done()
			elif _keys.visible:
				show_main()
			else:
				close()
	elif Input.is_action_just_pressed(&"pause") and not Game.ui_blocking \
			and Engine.get_process_frames() != Game.ui_closed_frame:
		open()


## While an action waits for its key, the next key pressed is it. Esc keeps
## the old one; a fixed key (arrows, Esc, `, F3) is not taken.
func _input(event: InputEvent) -> void:
	if waiting == &"" or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var ek := event as InputEventKey
	var k: Key = ek.physical_keycode if ek.physical_keycode != KEY_NONE else ek.keycode
	get_viewport().set_input_as_handled()
	_taken_frame = Engine.get_process_frames()
	if k == KEY_ESCAPE:
		stop_listening()
		return
	if Keys.reserved(k):
		return
	var action := waiting
	waiting = &""
	Game.bind_key(action, k)
	_refresh_keys()
	(_key_buttons[action] as Button).grab_focus()


## Waits for the next key for this action.
func listen(action: StringName) -> void:
	waiting = action
	_refresh_keys()


func stop_listening() -> void:
	var was := waiting
	waiting = &""
	_refresh_keys()
	if _key_buttons.has(was):
		(_key_buttons[was] as Button).grab_focus()


func show_keys() -> void:
	_main.visible = false
	_credits.visible = false
	_keys.visible = true
	_refresh_keys()
	_focus_first()


func show_credits() -> void:
	_fill_credits()
	_main.visible = false
	_keys.visible = false
	_credits.visible = true
	_credits_scroll.scroll_vertical = 0
	_focus_first()


## Back from the credits: to the menu, or to the title it was opened from.
func _credits_done() -> void:
	if _from_title:
		close()
	else:
		show_main()


func show_main() -> void:
	waiting = &""
	_keys.visible = false
	_credits.visible = false
	_main.visible = true
	_focus_first()


## On the pad there is no pointer: something must hold the focus.
func _focus_first() -> void:
	if not Game.pad:
		return
	if _keys.visible:
		(_key_buttons[Keys.REBIND[0][0]] as Button).grab_focus()
	elif _credits.visible:
		_credits_back.grab_focus()
	else:
		_resume.grab_focus()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _credits_scroll:
		# the credits hold a filled-in line (the version): built again on next open
		var body: Node = _credits_scroll.get_child(0)
		for c: Node in body.get_children():
			body.remove_child(c)
			c.queue_free()
	if what == NOTIFICATION_TRANSLATION_CHANGED and _sens_label:
		_labels()
		_refresh_keys()


func _labels() -> void:
	_sens_label.text = tr("UI_SENSITIVITY") % Game.mouse_sensitivity
	_vol_label.text = tr("UI_VOLUME") % roundi(Game.master_volume * 100.0)
	_fov_label.text = tr("UI_FOV") % roundi(Game.fov)
	_text_label.text = tr("UI_TEXT_SIZE") % roundi(Game.text_scale * 100.0)


func is_open() -> bool:
	return _root.visible


func open() -> void:
	_sens.set_value_no_signal(Game.mouse_sensitivity)
	_vol.set_value_no_signal(Game.master_volume)
	_fov.set_value_no_signal(Game.fov)
	_labels()
	_invert.set_pressed_no_signal(Game.invert_y)
	for b in _lang:
		b.set_pressed_no_signal(b.text.to_lower() == Game.language)
	_psx.set_pressed_no_signal(Game.psx_effects)
	_motion.set_pressed_no_signal(Game.head_bob)
	_captions.set_pressed_no_signal(Game.captions)
	_text.set_value_no_signal(Game.text_scale)
	_keys.visible = false
	_credits.visible = false
	_main.visible = true
	_root.visible = true
	get_tree().paused = true
	Game.ui_blocking = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_focus_first()


## The credits alone, from the title screen's menu.
func open_credits() -> void:
	open()
	_from_title = true
	show_credits()
	if not Game.pad:
		_credits_back.grab_focus()


func close() -> void:
	waiting = &""
	_root.visible = false
	if _from_title:
		# the title still holds the game: no captured mouse, no hand-over
		_from_title = false
		get_tree().paused = false
		Game.mark_ui_closed()
		credits_closed.emit()
		return
	get_tree().paused = false
	Game.ui_blocking = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func _on_sens(v: float) -> void:
	Game.mouse_sensitivity = v
	_sens_label.text = tr("UI_SENSITIVITY") % v
	Game.save_settings()


## The text grows under the player's eyes (the centre container keeps the
## bigger panel in the middle).
func _on_text(v: float) -> void:
	Game.set_text_scale(v)
	_labels()


func _on_volume(v: float) -> void:
	Game.set_volume(v)
	_vol_label.text = tr("UI_VOLUME") % roundi(v * 100.0)


func _on_fov(v: float) -> void:
	Game.set_fov(v)
	_fov_label.text = tr("UI_FOV") % roundi(v)
