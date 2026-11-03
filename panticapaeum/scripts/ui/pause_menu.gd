extends CanvasLayer
## Esc: pause the world, release the mouse, adjust settings.

signal closed

var _root: Control
var _sens_label: Label
var _sens: HSlider
var _invert: CheckBox
var _psx: CheckBox


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
	panel.custom_minimum_size = Vector2(620, 0)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position -= Vector2(310, 260)
	_root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	panel.add_child(col)
	var title := UiStyle.label("PAUSED", 40, UiStyle.BORDER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var resume := UiStyle.button("Resume")
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
	_invert = CheckBox.new()
	_invert.text = "Invert mouse Y"
	_invert.add_theme_font_size_override("font_size", 24)
	_invert.toggled.connect(func(on: bool) -> void:
		Game.invert_y = on
		Game.save_settings())
	col.add_child(_invert)
	_psx = CheckBox.new()
	_psx.text = "PS1 effects (low resolution, jitter, dither)"
	_psx.add_theme_font_size_override("font_size", 24)
	_psx.toggled.connect(func(on: bool) -> void:
		Game.psx_effects = on
		Game.save_settings())
	col.add_child(_psx)
	var quit := UiStyle.button("Quit to desktop")
	quit.pressed.connect(func() -> void: get_tree().quit())
	col.add_child(quit)
	var foot := UiStyle.label("History sections are sourced; story sections are fiction.", 18, UiStyle.MUTED)
	col.add_child(foot)
	_root.visible = false


func _process(_delta: float) -> void:
	if not Input.is_action_just_pressed(&"pause"):
		return
	if _root.visible:
		close()
	elif not Game.ui_blocking and Engine.get_process_frames() != Game.ui_closed_frame:
		open()


func is_open() -> bool:
	return _root.visible


func open() -> void:
	_sens.set_value_no_signal(Game.mouse_sensitivity)
	_sens_label.text = "Mouse sensitivity  %.2f" % Game.mouse_sensitivity
	_invert.set_pressed_no_signal(Game.invert_y)
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
	_sens_label.text = "Mouse sensitivity  %.2f" % v
	Game.save_settings()
