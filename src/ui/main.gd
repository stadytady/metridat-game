extends Control
## Game screen: wires Board/Levels/Progress to the view. No game rules here.

const HINT := "Нажатие на плитку сдвигает цвет клеток по её узору.\nСделай всё поле тёмным."

var _level := 1
var _board: Board
var _start: Board
var _par := 0
var _history := PackedInt32Array()
var _progress := Progress.new()

var _title: Label
var _info: Label
var _status: Label
var _view: BoardView
var _btn_prev: Button
var _btn_undo: Button
var _btn_restart: Button
var _btn_next: Button


func _ready() -> void:
	_build_ui()
	_progress.load_from()
	_load_level(_progress.unlocked)


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	margin.add_child(col)

	_title = _label(col, 36, Palette.TEXT)
	_info = _label(col, 22, Palette.MUTED)

	_view = BoardView.new()
	_view.size_flags_vertical = SIZE_EXPAND_FILL
	_view.pressed.connect(_on_cell_pressed)
	col.add_child(_view)

	_status = _label(col, 22, Palette.TEXT)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 64

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	_btn_prev = _button(row, "Назад", _prev)
	_btn_undo = _button(row, "Отменить", _undo)
	_btn_restart = _button(row, "Заново", _restart)
	_btn_next = _button(row, "Дальше", _next)


func _label(parent: Control, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = FOCUS_NONE
	b.custom_minimum_size = Vector2(120, 52)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _load_level(level: int) -> void:
	_level = clampi(level, 1, _progress.unlocked)
	var built := Levels.build(_level)
	_start = built.board
	_par = built.par
	_board = _start.copy()
	_history.clear()
	_view.board = _board
	_status.text = HINT if _level <= 2 else ""
	_refresh()


func _refresh() -> void:
	_title.text = "Уровень %d" % _level
	var best := ""
	if _progress.best.has(_level):
		best = "   ·   рекорд %d" % _progress.best[_level]
	_info.text = "Ходы %d   ·   минимум %d%s" % [_history.size(), _par, best]
	var solved := _board.is_solved()
	_btn_prev.disabled = _level <= 1
	_btn_next.disabled = _level >= _progress.unlocked
	_btn_undo.disabled = _history.is_empty() or solved
	_btn_restart.disabled = _history.is_empty()
	_view.queue_redraw()


func _on_cell_pressed(i: int) -> void:
	if _board.is_solved():
		return
	_board.press(i)
	_history.append(i)
	if _board.is_solved():
		_on_solved()
	_refresh()


func _on_solved() -> void:
	var moves := _history.size()
	var new_best := _progress.record(_level, moves)
	var err := _progress.save_to()
	if err != OK:
		push_warning("progress not saved: %s" % error_string(err))
	if moves <= _par:
		_status.text = "Идеально: %d ход(ов), это минимум." % moves
	else:
		_status.text = "Решено за %d. Можно за %d." % [moves, _par]
	if new_best and _progress.best.size() > 1:
		_status.text += " Новый рекорд."


func _undo() -> void:
	if _history.is_empty() or _board.is_solved():
		return
	_board.unpress(_history[-1])
	_history.resize(_history.size() - 1)
	_refresh()


func _restart() -> void:
	_board = _start.copy()
	_history.clear()
	_view.board = _board
	_status.text = ""
	_refresh()


func _prev() -> void:
	_load_level(_level - 1)


func _next() -> void:
	_load_level(_level + 1)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_Z, KEY_BACKSPACE:
			_undo()
		KEY_R:
			_restart()
		KEY_N, KEY_ENTER, KEY_RIGHT:
			if not _btn_next.disabled:
				_next()
		KEY_P, KEY_LEFT:
			if not _btn_prev.disabled:
				_prev()
		_:
			return
	get_viewport().set_input_as_handled()
