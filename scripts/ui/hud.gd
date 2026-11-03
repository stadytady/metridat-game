extends CanvasLayer
## Crosshair, interaction prompt, discovery counter, location and discovery toasts.


var _prompt: Label
var _counter: Label
var _toast: Label
var _hint: Label
var _toast_tween: Tween
var _perf: Label
var _click: Label
var _target: Node
var _lamps: Label
var _dusk_shown := false
var _toast_key := ""


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var cross := Control.new()
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cross)
	for r: Rect2 in [Rect2(-1, -7, 3, 5), Rect2(-1, 3, 3, 5), Rect2(-7, -1, 5, 3), Rect2(3, -1, 5, 3)]:
		var c := ColorRect.new()
		c.color = Color(1, 0.93, 0.8, 0.85)
		c.position = r.position * 1.5
		c.size = r.size * 1.5
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cross.add_child(c)

	_prompt = UiStyle.label("", 28)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position += Vector2(-600, 50)
	_prompt.size = Vector2(1200, 40)
	root.add_child(_prompt)

	_counter = UiStyle.label("", 26, UiStyle.BORDER)
	_counter.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_counter.position += Vector2(-460, 28)
	_counter.size = Vector2(430, 40)
	root.add_child(_counter)

	_lamps = UiStyle.label("", 22, UiStyle.MUTED)
	_lamps.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_lamps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lamps.position += Vector2(-460, 66)
	_lamps.size = Vector2(430, 36)
	_lamps.visible = false
	root.add_child(_lamps)

	_toast = UiStyle.label("", 34)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_toast.position = Vector2(40, 28)
	_toast.modulate.a = 0.0
	root.add_child(_toast)

	_perf = UiStyle.label("", 20, UiStyle.HISTORY)
	_perf.position = Vector2(40, 90)
	_perf.visible = false
	root.add_child(_perf)

	_click = UiStyle.label("UI_CLICK_TO_PLAY", 34, UiStyle.BORDER)
	_click.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_click.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_click.position += Vector2(-400, -120)
	_click.size = Vector2(800, 50)
	_click.visible = false
	root.add_child(_click)

	_hint = UiStyle.label("UI_HINT", 22, UiStyle.MUTED)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.position += Vector2(-700, -70)
	_hint.size = Vector2(1400, 40)
	root.add_child(_hint)
	var t := create_tween()
	t.tween_interval(10.0)
	t.tween_property(_hint, "modulate:a", 0.0, 2.0)

	Game.discovered.connect(_on_discovered)
	Game.lamp_lit.connect(_on_lamp_lit)
	Game.location_entered.connect(func(title: String) -> void: show_toast(title))
	_update_counter.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _counter:
		_update_counter()
		_on_target(_target)
		if _toast_key != "":
			_toast.text = tr(_toast_key)


func _process(_delta: float) -> void:
	_prompt.visible = not Game.ui_blocking
	_click.visible = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not Game.ui_blocking and not get_tree().paused
	if Input.is_action_just_pressed(&"perf_overlay"):
		_perf.visible = not _perf.visible
	if _perf.visible:
		_perf.text = perf_text()


## F3 overlay: what to report when checking performance on real hardware.
static func perf_text() -> String:
	return "FPS %d   %.2f ms   draws %d   tris %dk   vram %d MB   %s" % [
		Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576,
		RenderingServer.get_video_adapter_name(),
	]


func bind_interactor(interactor: Node) -> void:
	interactor.target_changed.connect(_on_target)


func _on_target(target: Node) -> void:
	_target = target
	_prompt.text = target.get_prompt() if target != null else ""


func _update_counter() -> void:
	_counter.text = tr("UI_DISCOVERIES") % [Game.found_count(), Game.total()]
	_lamps.text = tr("UI_LAMPS") % [Game.lamps_lit(), Game.lamps.size()]
	_lamps.visible = not Game.lamps.is_empty() and (Game.lamps_lit() > 0 or Game.time_target() >= 0.45)


func _on_discovered(_d: Discovery, is_new: bool) -> void:
	_update_counter()
	if not is_new:
		return
	if Game.found_count() == Game.total():
		show_toast("UI_NIGHT_HINT")
	elif Game.time_target() >= 0.45 and not _dusk_shown:
		_dusk_shown = true
		show_toast("UI_DUSK_HINT")


func _on_lamp_lit(lit: int, total: int) -> void:
	_update_counter()
	if lit == total:
		show_toast("UI_ALL_LIT")


## `key` is a translation key, so a language switch can re-render it.
func show_toast(key: String) -> void:
	_toast_key = key
	_toast.text = tr(key)
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.4)
	_toast_tween.tween_interval(3.5)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 1.2)


func set_visible_ui(on: bool) -> void:
	visible = on
