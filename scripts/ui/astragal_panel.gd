extends CanvasLayer
## The knucklebones table: four bones a hand counting 1, 3, 4 or 6, three
## throws; Aphrodite's throw beats all, the dog loses to all, else the higher sum. Opened by E at the children on the agora; E throws, Esc leaves.
## The rules live in AstragalGame; the bones are seen flying and coming down in
## AstragalTable, and the sums and the log fill in once they lie still.

signal closed

const CLATTER := preload("res://assets/audio/astragal.wav")
const GOLD := Color("#d9a75a")
const DASH := "\u2014"  # an empty cell; written as an escape so no editor can mangle it

var _game := AstragalGame.new()
var _panel: PanelContainer
var _sum_mine: Label
var _sum_theirs: Label
var _bones_mine: Label
var _bones_theirs: Label
var _log: VBoxContainer
var _foot: Label
var _clatter: AudioStreamPlayer
var _shown_throws := 0
var _table: AstragalTable
## The E that opened the table is still down: wait for it to come up before a
## key throws, or the first throw goes off by itself as the table opens.
var _armed := false
## The throw in the air, shown in the sums once its bones have landed.
var _pending: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 4
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiStyle.panel())
	_panel.custom_minimum_size = Vector2(760, 0)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	_panel.add_child(col)
	var title := UiStyle.label(tr("UI_ASTRAGAL_TITLE"), 40, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_table = AstragalTable.new()
	_table.name = "Table"
	_table.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_table)
	_table.landed.connect(func(_side: int) -> void:
		_clatter.pitch_scale = randf_range(0.94, 1.08)
		_clatter.play())
	_table.settled.connect(_on_settled)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 10)
	col.add_child(grid)
	grid.add_child(UiStyle.label("", 24, UiStyle.MUTED))
	grid.add_child(_head("UI_ASTRAGAL_YOU"))
	grid.add_child(_head("UI_ASTRAGAL_THEM"))
	grid.add_child(UiStyle.label("", 24, UiStyle.MUTED))
	_bones_mine = _body(DASH)
	_bones_theirs = _body(DASH)
	grid.add_child(_bones_mine)
	grid.add_child(_bones_theirs)
	grid.add_child(UiStyle.label(tr("UI_ASTRAGAL_SUM"), 24, UiStyle.MUTED))
	_sum_mine = _body(DASH)
	_sum_theirs = _body(DASH)
	grid.add_child(_sum_mine)
	grid.add_child(_sum_theirs)
	_log = VBoxContainer.new()
	_log.add_theme_constant_override("separation", 6)
	col.add_child(_log)
	_foot = UiStyle.label(tr("UI_ASTRAGAL_KEYS"), 20, UiStyle.MUTED)
	_foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_foot)
	_clatter = AudioStreamPlayer.new()
	_clatter.stream = CLATTER
	_clatter.volume_db = -9.0
	add_child(_clatter)
	_panel.visible = false


func _head(key: String) -> Label:
	var l := UiStyle.label(tr(key), 24, GOLD)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = 200
	return l


func _body(text: String) -> Label:
	var l := UiStyle.label(text, 26, UiStyle.TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func open() -> void:
	_panel.visible = true
	# the panel was built while hidden and a container skips sorting then: sort
	# the whole lot before measuring, or every cell inside the grid stays 0x0
	for c: Node in _panel.find_children("*", "Container", true, false):
		(c as Container).queue_sort()
	_panel.queue_sort()
	_panel.reset_size()
	_panel.position = ((Vector2(1920, 1080) - _panel.size) / 2.0).max(Vector2(40, 40))
	Game.ui_blocking = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_armed = not Input.is_action_pressed(&"interact")
	_refresh()


func close() -> void:
	_panel.visible = false
	Game.ui_blocking = false
	Game.mark_ui_closed()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()
	queue_free()


## The bones as their faces: a five is "1 4", not a row of pips.
func _faces(bones: Array[int]) -> String:
	var out := PackedStringArray()
	for b: int in bones:
		out.append(str(b))
	return " ".join(out)


## A sum, or the name of the throw when it is one that beats (or loses to) any sum.
func _sum_text(total: int, kind: String) -> String:
	if kind == AstragalGame.VENUS:
		return tr("UI_ASTRAGAL_VENUS")
	if kind == AstragalGame.DOG:
		return tr("UI_ASTRAGAL_DOG")
	return str(total)


func _refresh() -> void:
	var settled := _game.throws.size() - (0 if _pending.is_empty() else 1)
	if settled <= 0:
		_bones_mine.text = DASH
		_bones_theirs.text = DASH
		_sum_mine.text = DASH
		_sum_theirs.text = DASH
	else:
		var last: Dictionary = _game.throws[settled - 1]
		_bones_mine.text = _faces(last.mine)
		_bones_theirs.text = _faces(last.theirs)
		_sum_mine.text = _sum_text(last.sum_mine, last.kind_mine)
		_sum_theirs.text = _sum_text(last.sum_theirs, last.kind_theirs)
	_log.visible = settled > 0
	_foot.text = tr("UI_ASTRAGAL_AGAIN") if _game.over and _pending.is_empty() else tr("UI_ASTRAGAL_KEYS")


func _throw() -> void:
	var entry := _game.play_throw()
	if entry.is_empty():
		return
	_pending = entry
	_refresh()
	_table.throw_hands(entry.mine, entry.theirs, _game.throws.size())


## Both hands lie still: now the throw counts on the table.
func _on_settled() -> void:
	var entry := _pending
	if entry.is_empty():
		return
	_pending = {}
	var line := UiStyle.label("", 22, UiStyle.TEXT)
	var mark := "UI_ASTRAGAL_ROUND_WIN" if entry.winner == "me" else (
			"UI_ASTRAGAL_ROUND_LOSE" if entry.winner == "them" else "UI_ASTRAGAL_ROUND_DRAW")
	line.text = "%d.  %s : %s  (%s)" % [_game.throws.size(), _sum_text(entry.sum_mine, entry.kind_mine),
			_sum_text(entry.sum_theirs, entry.kind_theirs), tr(mark)]
	_log.add_child(line)
	_refresh()
	if _game.over:
		var verdict := UiStyle.label("", 28, GOLD)
		verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var key := "UI_ASTRAGAL_WIN" if _game.winner == "me" else (
				"UI_ASTRAGAL_LOSE" if _game.winner == "them" else "UI_ASTRAGAL_DRAW")
		verdict.text = tr(key)
		_log.add_child(verdict)
		_panel.reset_size()
		_panel.position = ((Vector2(1920, 1080) - _panel.size) / 2.0).max(Vector2(40, 40))


## Whether a throw is still in the air (the walkthrough and tests wait on it).
func throwing() -> bool:
	return not _pending.is_empty()


func _process(_delta: float) -> void:
	if not _panel.visible:
		return
	if Input.is_action_just_pressed(&"pause"):
		close()
		return
	_key(Input.is_action_pressed(&"interact"), Input.is_action_just_pressed(&"interact"))


## E: held down since the table opened it does nothing; once let go, a press
## throws (or starts a new game after the third throw). Not while bones fly.
func _key(down: bool, just: bool) -> void:
	if not down:
		_armed = true
		return
	if _armed and just and _pending.is_empty():
		if _game.over:
			for c in _log.get_children():
				c.queue_free()
			_game.restart()
			_table.clear()
			_refresh()
		else:
			_throw()
