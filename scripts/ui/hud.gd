extends CanvasLayer
## Crosshair, interaction prompt, discovery counter, location and discovery toasts.


var _prompt: Label
var _counter: Label
var _toast: Label
var _hint: KeysBar
var _toast_tween: Tween
var _perf: Label
var _target: Node
var _legend_tween: Tween
var _lamps: Label
var _dusk_shown := false
var _toast_key := ""
var _toast_prefix := ""
var popup: AchievementPopup


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# No crosshair: a clean picture. What the view centres on is announced by
	# the prompt below ("[E] Inspect ...") when it can be used.
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


	# The controls legend: key caps in one quiet strip along the bottom.
	_hint = KeysBar.new()
	_hint.name = "KeysBar"
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.position += Vector2(-760, -58)
	_hint.size = Vector2(1520, 40)
	root.add_child(_hint)
	show_legend(14.0)
	# picking up the pad (or putting it down) shows the legend again, in its buttons
	Game.device_changed.connect(func() -> void: show_legend(6.0))

	Game.discovered.connect(_on_discovered)
	Game.lamp_lit.connect(_on_lamp_lit)
	Game.state_restored.connect(_update_counter)
	# a moved key or the pad picked up: the prompt and the toast name the new key
	Game.device_changed.connect(_refill)
	Game.settings_changed.connect(_refill)
	Game.location_entered.connect(func(title: String) -> void: show_toast(title))
	Game.quest_changed.connect(_on_quest)
	# Achievements get the Steam-style card, not the plain toast. It needs a canvas
	# layer of its own: the info, dialogue and journal panels are canvas layers too,
	# so a card drawn inside the HUD would sit *behind* them and never be seen while
	# a find is open.
	var overlay := CanvasLayer.new()
	overlay.name = "Overlay"
	overlay.layer = 6
	add_child(overlay)
	popup = AchievementPopup.new()
	popup.name = "AchievementPopup"
	overlay.add_child(popup)
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Achievements.unlocked_signal.connect(func(id: String) -> void: popup.push(id))
	_update_counter.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _counter:
		_update_counter()
		_on_target(_target)
		if _toast_key != "":
			_toast.text = _toast_text()


func _process(_delta: float) -> void:
	_prompt.visible = not Game.ui_blocking
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
	_prompt.text = Keys.fill(target.get_prompt()) if target != null else ""


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


## An errand taken, its thing found, or brought back: one line, like a place name.
func _on_quest(id: String, state: int) -> void:
	var prefix := {Quests.TAKEN: "UI_QUEST_TAKEN", Quests.FOUND: "UI_QUEST_FOUND", Quests.DONE: "UI_QUEST_DONE"}
	if prefix.has(state):
		show_toast(String(Quests.LIST[id]["title"]), prefix[state])


func _on_lamp_lit(lit: int, total: int) -> void:
	_update_counter()
	if lit == total:
		show_toast("UI_ALL_LIT")


## `key` is a translation key, so a language switch can re-render it. With a
## `prefix_key` the toast wraps it, as in "Achievement: the first find".
func show_toast(key: String, prefix_key: String = "") -> void:
	_toast_key = key
	_toast_prefix = prefix_key
	_toast.text = _toast_text()
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.4)
	_toast_tween.tween_interval(3.5)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 1.2)


## Puts the toast out at once: the shots jump from place to place faster than
## it fades, and a frame of one place carried the name of the one before.
func clear_toast() -> void:
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 0.0
	_toast_key = ""
	_toast_prefix = ""


## Shows the controls legend for `hold` seconds, then fades it out.
func show_legend(hold: float) -> void:
	if _legend_tween:
		_legend_tween.kill()
	_hint.modulate.a = 1.0
	_legend_tween = create_tween()
	_legend_tween.tween_interval(hold)
	_legend_tween.tween_property(_hint, "modulate:a", 0.0, 2.0)


func _refill() -> void:
	if _prompt == null:
		return
	_on_target(_target if is_instance_valid(_target) else null)
	if _toast_key != "":
		_toast.text = _toast_text()


func _toast_text() -> String:
	if _toast_prefix != "":
		return Keys.fill(tr(_toast_prefix) % tr(_toast_key))
	return Keys.fill(tr(_toast_key))


func set_visible_ui(on: bool) -> void:
	visible = on
