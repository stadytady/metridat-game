extends CanvasLayer
## Journal (J): every find in walking order. Found ones by name and place,
## and a click opens them again in the info panel's viewer; the rest as
## "? ? ?" with a hint where to look, so no find stays lost.

## Walking order of the districts; finds sort by it, then by id.
const ORDER := ["LOC_HILL", "LOC_STREET", "LOC_AGORA", "LOC_SHORE", "LOC_SANCTUARY", "LOC_DREAM"]

var _panel: PanelContainer
var _title: Label
var _rows: VBoxContainer
var _opened_frame := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiStyle.panel())
	_panel.custom_minimum_size = Vector2(1000, 0)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_panel.add_child(col)
	_title = UiStyle.label("", 34, UiStyle.BORDER)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	var foot := UiStyle.label("UI_JOURNAL_KEYS", 20, UiStyle.MUTED)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for n: Control in [_title, _rows, foot]:
		col.add_child(n)
	_panel.visible = false


static func ordered(registry: Dictionary) -> Array[Discovery]:
	var out: Array[Discovery] = []
	for d: Discovery in registry.values():
		if d.epilogue and not Game.found.has(d.id):
			continue  # the dream's find shows only once found
		out.append(d)
	out.sort_custom(func(a: Discovery, b: Discovery) -> bool:
		var ia := ORDER.find(a.location)
		var ib := ORDER.find(b.location)
		return ia < ib if ia != ib else String(a.id) < String(b.id))
	return out


func is_open() -> bool:
	return _panel.visible


## Number of rows shown, and how many of them are hints (for the walkthrough).
func counts() -> Vector2i:
	var hints := 0
	for r in _rows.get_children():
		hints += int(r.get_meta(&"hint", false))
	return Vector2i(_rows.get_child_count(), hints)


func _fill() -> void:
	_title.text = tr("UI_JOURNAL") % [Game.found_count(), Game.total()]
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	for d in ordered(Game.registry):
		var found: bool = Game.found.has(d.id)
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		var head := HBoxContainer.new()
		var title := UiStyle.label(tr(d.title) if found else tr("UI_JOURNAL_UNKNOWN"), 24, UiStyle.TEXT if found else UiStyle.MUTED)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(title)
		head.add_child(UiStyle.label(tr(d.location), 20, UiStyle.MUTED))
		row.add_child(head)
		if not found:
			var hint := UiStyle.label(tr(d.hint), 20, UiStyle.FICTION)
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hint.custom_minimum_size.x = 960
			row.add_child(hint)
		row.set_meta(&"hint", not found)
		if found:
			row.mouse_filter = Control.MOUSE_FILTER_STOP
			row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			row.gui_input.connect(_on_row_input.bind(d))
			row.mouse_entered.connect(func() -> void: title.add_theme_color_override("font_color", UiStyle.BORDER))
			row.mouse_exited.connect(func() -> void: title.add_theme_color_override("font_color", UiStyle.TEXT))
		_rows.add_child(row)
	_panel.reset_size()
	_panel.position = ((Vector2(1920, 1080) - _panel.size) / 2.0).max(Vector2(40, 40))


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _panel and _panel.visible:
		_fill()


func open() -> void:
	_fill()
	_panel.visible = true
	_opened_frame = Engine.get_process_frames()
	Game.ui_blocking = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # rows are clickable


## `hand_back`: give the cursor back to the game (not when another panel opens).
func close(hand_back: bool = true) -> void:
	_panel.visible = false
	Game.ui_blocking = false
	Game.mark_ui_closed()
	if hand_back:
		Game.inspect_closed.emit()


## Opens a found row in the info panel (the same view as on inspection).
func view(d: Discovery) -> void:
	close(false)
	get_parent().get_node("InfoPanel").show_discovery(d)


func _on_row_input(event: InputEvent, d: Discovery) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		view(d)


func _process(_delta: float) -> void:
	if not _panel.visible:
		if Input.is_action_just_pressed(&"journal") and not Game.ui_blocking and not get_tree().paused:
			open()
		return
	# The J that opened it must not close it in the same frame.
	if Engine.get_process_frames() <= _opened_frame + 1:
		return
	if Input.is_action_just_pressed(&"journal") or Input.is_action_just_pressed(&"pause"):
		close()
