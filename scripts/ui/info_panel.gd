extends CanvasLayer
## Panel shown when an object is inspected. History (established, with
## sources) and the game's own story are separate, labelled sections.

var _panel: PanelContainer
var _title: Label
var _where: Label
var _desc: Label
var _hist: Label
var _src: Label
var _story: Label
var _opened_frame := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiStyle.panel())
	_panel.custom_minimum_size = Vector2(820, 0)
	_panel.position = Vector2(1920 - 820 - 60, 120)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)
	_title = UiStyle.label("", 36, UiStyle.BORDER)
	_where = UiStyle.label("", 22, UiStyle.MUTED)
	_desc = _wrap(UiStyle.label("", 24))
	var h1 := UiStyle.label("HISTORICAL RECORD", 22, UiStyle.HISTORY)
	_hist = _wrap(UiStyle.label("", 23))
	_src = _wrap(UiStyle.label("", 19, UiStyle.MUTED))
	var h2 := UiStyle.label("STORY  (fiction, invented for this game)", 22, UiStyle.FICTION)
	_story = _wrap(UiStyle.label("", 23, Color("#e8c9a8")))
	var foot := UiStyle.label("[E] or [ESC] close", 20, UiStyle.MUTED)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for n: Control in [_title, _where, _desc, _sep(), h1, _hist, _src, _sep(), h2, _story, foot]:
		col.add_child(n)
	_panel.visible = false
	Game.discovered.connect(_on_discovered)


func _wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 780
	return l


func _sep() -> Control:
	var c := ColorRect.new()
	c.color = Color(UiStyle.BORDER, 0.5)
	c.custom_minimum_size = Vector2(0, 2)
	return c


func is_open() -> bool:
	return _panel.visible


func _on_discovered(d: Discovery, _is_new: bool) -> void:
	_title.text = d.title
	_where.text = d.location
	_desc.text = d.description
	_hist.text = d.history
	_src.text = "Sources: " + d.sources
	_story.text = d.narrative
	_panel.visible = true
	_panel.reset_size()
	_panel.position.y = maxf(40.0, (1080.0 - _panel.size.y) / 2.0)
	_opened_frame = Engine.get_process_frames()
	Game.ui_blocking = true


func close() -> void:
	_panel.visible = false
	Game.ui_blocking = false
	Game.ui_closed_frame = Engine.get_process_frames()
	Game.inspect_closed.emit()


func _process(_delta: float) -> void:
	# The E that opened the panel must not close it in the same frame.
	if not _panel.visible or Engine.get_process_frames() <= _opened_frame + 1:
		return
	if Input.is_action_just_pressed(&"interact") or Input.is_action_just_pressed(&"pause"):
		close()
