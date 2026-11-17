extends CanvasLayer
## Sosias lets the player strike staters: a blank on the anvil, his punch on it,
## the player's hammer - one blow a coin, three blanks. A needle runs over a
## meter with the swing and a gold mark shows where the punch stands upright; E
## strikes. MintGame has the rules, CoinView draws each coin. After the third,
## E lays out three new blanks and Esc / B leaves. Opened by Mint once his talk
## is over (Game.request_mint).

signal closed
## A coin was struck: "crisp", "doubled" or "off_centre".
signal struck(quality: String)

const HAMMER := preload("res://assets/audio/hammer.wav")
const GOLD := Color("#d9a75a")
const METER := Vector2(560, 34)
## What each coin is called under it (spelled out: test_i18n looks for whole keys).
const NAMES := {"crisp": "UI_MINT_CRISP", "doubled": "UI_MINT_DOUBLED", "off_centre": "UI_MINT_OFF_CENTRE"}

var game := MintGame.new()
var _panel: PanelContainer
var _coins: Array[CoinView] = []
var _meter: Control
var _blows: Label
var _verdict: Label
var _foot: Label
var _hammer: AudioStreamPlayer
## The E that closed the talk may still be down: it must come up before a key
## strikes, or the first blow goes off by itself as the panel opens.
var _armed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 4
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiStyle.panel())
	_panel.custom_minimum_size = Vector2(720, 0)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	_panel.add_child(col)
	var title := UiStyle.label(tr("UI_MINT_TITLE"), 40, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var hint := UiStyle.label(tr("UI_MINT_HINT"), 20, UiStyle.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 640
	col.add_child(hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	for i in MintGame.BLANKS:
		var c := CoinView.new()
		row.add_child(c)
		_coins.append(c)
	_meter = Control.new()
	_meter.custom_minimum_size = METER
	_meter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_meter.draw.connect(_draw_meter)
	col.add_child(_meter)
	_blows = UiStyle.label("", 24, UiStyle.TEXT)
	_blows.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_blows)
	_verdict = UiStyle.label("", 26, GOLD)
	_verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# a fixed measure: a long verdict wraps instead of widening the panel
	_verdict.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_verdict.custom_minimum_size.x = 640
	col.add_child(_verdict)
	_foot = UiStyle.label("", 20, UiStyle.MUTED)
	_foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Keys.bind(_foot, "UI_MINT_KEYS")
	col.add_child(_foot)
	_hammer = AudioStreamPlayer.new()
	_hammer.stream = HAMMER
	_hammer.volume_db = -4.0
	add_child(_hammer)
	_panel.visible = false


func open() -> void:
	_panel.visible = true
	for c: Node in _panel.find_children("*", "Container", true, false):
		(c as Container).queue_sort()
	_panel.queue_sort()
	_panel.reset_size()
	_panel.position = UiStyle.centred(self, _panel.size)
	Game.ui_blocking = true
	_armed = not Input.is_action_pressed(&"interact")
	game.reset()
	_refresh()


func close() -> void:
	_panel.visible = false
	Game.ui_blocking = false
	Game.mark_ui_closed()
	closed.emit()
	queue_free()


func is_open() -> bool:
	return _panel.visible


func _process(delta: float) -> void:
	if not _panel.visible:
		return
	if Input.is_action_just_pressed(&"back"):
		close()
		return
	if not game.over():
		game.clock += delta
	_meter.queue_redraw()
	key(Input.is_action_pressed(&"interact"), Input.is_action_just_pressed(&"interact"))


## E: held since the panel opened it does nothing; once let go, a press strikes
## (or, after the third blow, lays a new blank on the anvil).
func key(down: bool, just: bool) -> void:
	if not down:
		_armed = true
		return
	if not (_armed and just):
		return
	if game.over():
		game.reset()
		_refresh()
		return
	var g := game.strike()
	_hammer.pitch_scale = 1.0 if g == MintGame.TRUE else (0.92 if g == MintGame.GLANCE else 0.84)
	_hammer.play()
	_refresh()
	struck.emit(MintGame.quality(g))


func _refresh() -> void:
	var marks := PackedStringArray()
	for i in MintGame.BLANKS:
		var g: int = game.grades[i] if i < game.grades.size() else -1
		_coins[i].show_blow(g, i)
		marks.append(tr(NAMES[MintGame.quality(g)]) if g >= 0 else "\u2014")
	_blows.text = "   ".join(marks)
	var best: int = game.grades.max() if not game.grades.is_empty() else -1
	_verdict.text = tr("UI_MINT_DONE_CRISP" if best == MintGame.TRUE else "UI_MINT_DONE") if game.over() else ""
	Keys.bind(_foot, "UI_MINT_AGAIN" if game.over() else "UI_MINT_KEYS")
	# the verdict comes and goes: keep the panel fitted and in the middle
	_panel.reset_size()
	_panel.position = UiStyle.centred(self, _panel.size)


func _draw_meter() -> void:
	var w := METER.x
	var h := METER.y
	_meter.draw_rect(Rect2(Vector2.ZERO, METER), Color(0.08, 0.06, 0.04, 0.9))
	_meter.draw_rect(Rect2(Vector2.ZERO, METER), Color(GOLD, 0.6), false, 2.0)
	if game.over():
		return
	var m := MintGame.mark(game.clock, game.grades.size())
	var near := MintGame.MARK_HALF * MintGame.NEAR
	_meter.draw_rect(Rect2(Vector2((m - near) * w, 4), Vector2(near * 2.0 * w, h - 8)), Color(GOLD, 0.22))
	_meter.draw_rect(Rect2(Vector2((m - MintGame.MARK_HALF) * w, 4), Vector2(MintGame.MARK_HALF * 2.0 * w, h - 8)), Color(GOLD, 0.75))
	var x := MintGame.needle(game.clock) * w
	_meter.draw_line(Vector2(x, -6), Vector2(x, h + 6), Color("#f2e6cc"), 4.0)
