extends CanvasLayer
## Panel shown when an object is inspected: the find large on the left (an
## ItemViewer the player can turn), the texts on the right: what the find is,
## and what is historically established about such things, with sources. No
## fiction page: what the game made up is listed in README.

const TEXT_W := 820.0

var _panel: PanelContainer
var _title: Label
var _where: Label
var _desc: Label
var _hist: Label
var _src: Label
## The texts scroll when they are taller than the screen leaves room for (a
## long history at a large text size); the close hint stays below them.
var _scroll: ScrollContainer
var _col: VBoxContainer
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
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 10)
	row.add_child(side)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(_scroll)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size.x = TEXT_W
	_scroll.add_child(col)
	_col = col
	_title = UiStyle.label("", 36, UiStyle.BORDER)
	_where = UiStyle.label("", 22, UiStyle.MUTED)
	_desc = _wrap(UiStyle.label("", 24))
	var h1 := UiStyle.label("UI_HISTORY", 22, UiStyle.HISTORY)
	_hist = _wrap(UiStyle.label("", 23))
	_src = _wrap(UiStyle.label("", 19, UiStyle.MUTED))
	var foot := UiStyle.label("", 20, UiStyle.MUTED)
	Keys.bind(foot, "UI_CLOSE")
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for n: Control in [_title, _where, _desc, _sep(), h1, _hist, _src]:
		col.add_child(n)
	side.add_child(foot)
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
	_center()


## A ScrollContainer asks for no height of its own: give it the texts' height,
## but no more than the screen has room for, and start at the top.
func _center() -> void:
	_scroll.custom_minimum_size.y = minf(_col.get_combined_minimum_size().y, UiStyle.screen(self).y - 170.0)
	_scroll.scroll_vertical = 0
	_panel.reset_size()
	_panel.position = UiStyle.centred(self, _panel.size)


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


func _process(delta: float) -> void:
	# The E that opened the panel must not close it in the same frame.
	if not _panel.visible or Engine.get_process_frames() <= _opened_frame + 1:
		return
	# the long texts scroll on the stick or the arrows too, not only the wheel
	var dy := Input.get_axis(&"ui_up", &"ui_down")
	if absf(dy) > 0.2:
		_scroll.scroll_vertical += roundi(dy * 900.0 * delta)
	if Input.is_action_just_pressed(&"interact") or Input.is_action_just_pressed(&"back"):
		close()
