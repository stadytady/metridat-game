extends CanvasLayer
## Esc: pause the world, release the mouse, adjust settings.

signal closed

var _root: Control
var _sens_label: Label
var _sens: HSlider
var _vol_label: Label
var _vol: HSlider
var _invert: CheckBox
var _psx: CheckBox
var _lang: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel())
	panel.custom_minimum_size = Vector2(760, 0)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position -= Vector2(380, 340)
	_root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	panel.add_child(col)
	var title := UiStyle.label("UI_PAUSED", 40, UiStyle.BORDER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var resume := UiStyle.button("UI_RESUME")
	resume.pressed.connect(close)
	col.add_child(resume)

	_sens_label = UiStyle.label("", 24)
	col.add_child(_sens_label)
	_sens = HSlider.new()
	_sens.min_value = 0.1
	_sens.max_value = 4.0
	_sens.step = 0.05
	_sens.custom_minimum_size = Vector2(560, 32)
	_sens.value_changed.connect(_on_sens)
	col.add_child(_sens)
	_vol_label = UiStyle.label("", 24)
	col.add_child(_vol_label)
	_vol = HSlider.new()
	_vol.min_value = 0.0
	_vol.max_value = 1.0
	_vol.step = 0.05
	_vol.custom_minimum_size = Vector2(560, 32)
	_vol.value_changed.connect(_on_volume)
	col.add_child(_vol)
	_invert = CheckBox.new()
	_invert.text = "UI_INVERT_Y"
	_invert.add_theme_font_size_override("font_size", 24)
	_invert.toggled.connect(func(on: bool) -> void:
		Game.invert_y = on
		Game.save_settings())
	col.add_child(_invert)
	_psx = CheckBox.new()
	_psx.text = "UI_PSX"
	_psx.add_theme_font_size_override("font_size", 24)
	_psx.toggled.connect(func(on: bool) -> void:
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
	var quit := UiStyle.button("UI_QUIT")
	quit.pressed.connect(func() -> void:
		Game.save_requested.emit()
		get_tree().quit())
	col.add_child(quit)
	var foot := UiStyle.label("UI_FOOTNOTE", 18, UiStyle.MUTED)
	col.add_child(foot)
	_root.visible = false


func _process(_delta: float) -> void:
	if not Input.is_action_just_pressed(&"pause"):
		return
	if _root.visible:
		close()
	elif not Game.ui_blocking and Engine.get_process_frames() != Game.ui_closed_frame:
		open()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _sens_label:
		_sens_label.text = tr("UI_SENSITIVITY") % Game.mouse_sensitivity
		_vol_label.text = tr("UI_VOLUME") % roundi(Game.master_volume * 100.0)


func is_open() -> bool:
	return _root.visible


func open() -> void:
	_sens.set_value_no_signal(Game.mouse_sensitivity)
	_sens_label.text = tr("UI_SENSITIVITY") % Game.mouse_sensitivity
	_vol.set_value_no_signal(Game.master_volume)
	_vol_label.text = tr("UI_VOLUME") % roundi(Game.master_volume * 100.0)
	_invert.set_pressed_no_signal(Game.invert_y)
	for b in _lang:
		b.set_pressed_no_signal(b.text.to_lower() == Game.language)
	_psx.set_pressed_no_signal(Game.psx_effects)
	_root.visible = true
	get_tree().paused = true
	Game.ui_blocking = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
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
