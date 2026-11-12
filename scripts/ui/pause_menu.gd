extends CanvasLayer
## Esc (or START): pause the world, release the mouse, adjust settings. A second
## page moves the keys. Walked with the mouse, or with the stick and A on a pad.

signal closed

var _root: Control
var _main: VBoxContainer
var _keys: VBoxContainer
var _resume: Button
var _sens_label: Label
var _sens: HSlider
var _vol_label: Label
var _vol: HSlider
var _fov_label: Label
var _fov: HSlider
var _invert: CheckBox
var _psx: CheckBox
var _lang: Array[Button] = []
## action -> its key button on the controls page.
var _key_buttons := {}
var _keys_back: Button
## The action waiting for its new key (&"" when none), and the frame a key
## press was taken for it: that Esc must not also close the menu.
var waiting: StringName = &""
var _taken_frame := -1


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
	_sens_label = UiStyle.label("", 24)
	col.add_child(_sens_label)
	_sens = _slider(0.1, 4.0, 0.05, _on_sens)
	col.add_child(_sens)
	_vol_label = UiStyle.label("", 24)
	col.add_child(_vol_label)
	_vol = _slider(0.0, 1.0, 0.05, _on_volume)
	col.add_child(_vol)
	_fov_label = UiStyle.label("", 24)
	col.add_child(_fov_label)
	_fov = _slider(Game.FOV_MIN, Game.FOV_MAX, 1.0, _on_fov)
	col.add_child(_fov)
	_invert = _check("UI_INVERT_Y", func(on: bool) -> void:
		Game.invert_y = on
		Game.save_settings())
	col.add_child(_invert)
	_psx = _check("UI_PSX", func(on: bool) -> void:
		Game.psx_effects = on
		Game.save_settings())
	col.add_child(_psx)
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
	col.add_child(lang_row)
	var controls := UiStyle.button("UI_CONTROLS")
	controls.pressed.connect(show_keys)
	col.add_child(controls)
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


func _slider(lo: float, hi: float, step: float, on_change: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size = Vector2(560, 32)
	s.value_changed.connect(on_change)
	return s


func _check(key: String, on_toggle: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = key
	c.add_theme_font_size_override("font_size", 24)
	c.toggled.connect(on_toggle)
	return c


func _refresh_keys() -> void:
	for action: StringName in _key_buttons:
		var b: Button = _key_buttons[action]
		b.text = tr("UI_PRESS_KEY") if action == waiting else Keys.key_name(Game.key_for(action))


func _process(_delta: float) -> void:
	if waiting != &"" or Engine.get_process_frames() == _taken_frame:
		return
	if _root.visible:
		if Input.is_action_just_pressed(&"pause") or Input.is_action_just_pressed(&"back"):
			if _keys.visible:
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
	_keys.visible = true
	_refresh_keys()
	_focus_first()


func show_main() -> void:
	waiting = &""
	_keys.visible = false
	_main.visible = true
	_focus_first()


## On the pad there is no pointer: something must hold the focus.
func _focus_first() -> void:
	if not Game.pad:
		return
	if _keys.visible:
		(_key_buttons[Keys.REBIND[0][0]] as Button).grab_focus()
	else:
		_resume.grab_focus()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _sens_label:
		_labels()
		_refresh_keys()


func _labels() -> void:
	_sens_label.text = tr("UI_SENSITIVITY") % Game.mouse_sensitivity
	_vol_label.text = tr("UI_VOLUME") % roundi(Game.master_volume * 100.0)
	_fov_label.text = tr("UI_FOV") % roundi(Game.fov)


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
	_keys.visible = false
	_main.visible = true
	_root.visible = true
	get_tree().paused = true
	Game.ui_blocking = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_focus_first()


func close() -> void:
	waiting = &""
	_root.visible = false
	get_tree().paused = false
	Game.ui_blocking = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func _on_sens(v: float) -> void:
	Game.mouse_sensitivity = v
	_sens_label.text = tr("UI_SENSITIVITY") % v
	Game.save_settings()


func _on_volume(v: float) -> void:
	Game.set_volume(v)
	_vol_label.text = tr("UI_VOLUME") % roundi(v * 100.0)


func _on_fov(v: float) -> void:
	Game.set_fov(v)
	_fov_label.text = tr("UI_FOV") % roundi(v)
