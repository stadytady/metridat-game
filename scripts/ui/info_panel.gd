extends CanvasLayer
## Panel shown when an object is inspected: the find large on the left (an
## ItemViewer the player can turn), the texts on the right. History
## (established, with sources) and the game's own story are separate,
## labelled sections.

const TEXT_W := 820.0

var _panel: PanelContainer
var _title: Label
var _where: Label
var _desc: Label
var _hist: Label
var _src: Label
var _story: Label
var _opened_frame := -1
var _shown: Discovery
var viewer: ItemViewer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiStyle.panel())
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	_panel.add_child(row)
	viewer = ItemViewer.new()
	viewer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(viewer)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size.x = TEXT_W
	row.add_child(col)
	_title = UiStyle.label("", 36, UiStyle.BORDER)
	_where = UiStyle.label("", 22, UiStyle.MUTED)
	_desc = _wrap(UiStyle.label("", 24))
	var h1 := UiStyle.label("UI_HISTORY", 22, UiStyle.HISTORY)
	_hist = _wrap(UiStyle.label("", 23))
	_src = _wrap(UiStyle.label("", 19, UiStyle.MUTED))
	var h2 := UiStyle.label("UI_STORY", 22, UiStyle.FICTION)
	_story = _wrap(UiStyle.label("", 23, Color("#e8c9a8")))
	var foot := UiStyle.label("UI_CLOSE", 20, UiStyle.MUTED)
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _shown and _panel.visible:
		_fill(_shown)


func _fill(d: Discovery) -> void:
	_shown = d
	_title.text = tr(d.title)
	_where.text = tr(d.location)
	_desc.text = tr(d.description)
	_hist.text = tr(d.history)
	_src.text = tr("UI_SOURCES") % d.sources
	_story.text = tr(d.narrative)
	_center()


func _center() -> void:
	_panel.reset_size()
	_panel.position = ((Vector2(1920, 1080) - _panel.size) / 2.0).max(Vector2(40, 40))


func _on_discovered(d: Discovery, _is_new: bool) -> void:
	show_discovery(d)


## Opens the panel for a find (on inspection, or from the journal).
func show_discovery(d: Discovery) -> void:
	_fill(d)
	viewer.show_model(d.model)
	_panel.visible = true
	viewer.set_active(true)
	_center()
	_opened_frame = Engine.get_process_frames()
	Game.ui_blocking = true
	# A free cursor to turn the find; Main captures it again on close.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	_panel.visible = false
	viewer.set_active(false)
	Game.ui_blocking = false
	Game.mark_ui_closed()
	Game.inspect_closed.emit()


func _process(_delta: float) -> void:
	# The E that opened the panel must not close it in the same frame.
	if not _panel.visible or Engine.get_process_frames() <= _opened_frame + 1:
		return
	if Input.is_action_just_pressed(&"interact") or Input.is_action_just_pressed(&"pause"):
		close()
