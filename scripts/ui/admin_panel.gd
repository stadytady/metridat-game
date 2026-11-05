class_name AdminPanel
extends CanvasLayer
## The developer menu on the tilde key: the hour of the day, and a jump to any of
## the viewpoints the screenshots use. Deliberately not in the controls legend and
## not translated like a player-facing panel — it is a tool, not a feature.

signal travelled(place: String)

const WORLD := preload("res://scripts/world/world.gd")

const PAGE_TIME := 0
const PAGE_PLACES := 1
## The clock: -1 hands the hour back to the finds, the rest are fixed hours.
const TIME_STEPS := [-1.0, 0.25, 0.5, 0.72, 0.78, 0.9, 1.0, 1.25]
const TIME_KEYS := [
	"UI_ADMIN_NORMAL", "UI_ADMIN_MORNING", "UI_ADMIN_NOON", "UI_ADMIN_SUNSET",
	"UI_ADMIN_DUSK", "UI_ADMIN_NIGHT", "UI_ADMIN_LATE", "UI_ADMIN_DREAM",
]
const ROWS := 8

var _card: PanelContainer
var _title: Label
var _tabs: Array[Label] = []
var _body: VBoxContainer
var _hints: Label
var _page := PAGE_TIME
var _sel := [0, 0]
var _scroll := [0, 0]
var _places: PackedStringArray = []
## Viewpoint names that already have a place name in the string table.
const PLACE_KEYS := {
	"hill": "LOC_HILL", "hill_wide": "LOC_HILL", "street": "LOC_STREET", "street_up": "LOC_STREET",
	"agora": "LOC_AGORA", "workshop": "LOC_AGORA", "fishing": "LOC_SHORE", "shore": "LOC_SHORE",
	"theatre": "LOC_HILL", "masks": "LOC_HILL", "house_lane": "LOC_STREET", "house_yard": "LOC_STREET",
	"house_room": "LOC_STREET", "sanctuary": "LOC_SANCTUARY", "sacred_way": "LOC_SANCTUARY",
	"pier": "LOC_SHORE", "harbour": "LOC_SHORE", "dream": "LOC_DREAM",
}


func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_places = WORLD.viewpoints().keys()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", UiStyle.panel())
	_card.custom_minimum_size = Vector2(760, 0)
	add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_card.add_child(col)
	_title = UiStyle.label(tr("UI_ADMIN_TITLE"), 26, UiStyle.BORDER)
	col.add_child(_title)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 18)
	col.add_child(tabs)
	for i in 2:
		var l := UiStyle.label(tr("UI_ADMIN_TIME" if i == PAGE_TIME else "UI_ADMIN_PLACES"), 19, UiStyle.MUTED)
		tabs.add_child(l)
		_tabs.append(l)
	col.add_child(_rule())
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 2)
	col.add_child(_body)
	col.add_child(_rule())
	_hints = UiStyle.label(tr("UI_ADMIN_KEYS"), 16, UiStyle.MUTED)
	col.add_child(_hints)
	_refresh()


func _rule() -> Control:
	var line := ColorRect.new()
	line.color = Color(0.55, 0.4, 0.2, 0.7)
	line.custom_minimum_size = Vector2(0, 1)
	return line


func open() -> void:
	visible = true
	_refresh()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	visible = false
	Game.mark_ui_closed()


func is_open() -> bool:
	return visible


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"admin"):
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	if event.is_action_pressed(&"move_up"):
		_move(-1)
	elif event.is_action_pressed(&"move_down"):
		_move(1)
	elif event.is_action_pressed(&"move_left"):
		_page = PAGE_TIME
		_refresh()
	elif event.is_action_pressed(&"move_right"):
		_page = PAGE_PLACES
		_refresh()
	elif event.is_action_pressed(&"interact"):
		_apply()
	elif event.is_action_pressed(&"pause"):
		close()


func _move(step: int) -> void:
	var n := _count()
	if n == 0:
		return
	_sel[_page] = posmod(int(_sel[_page]) + step, n)
	if _sel[_page] < _scroll[_page]:
		_scroll[_page] = _sel[_page]
	if _sel[_page] >= _scroll[_page] + ROWS:
		_scroll[_page] = _sel[_page] - ROWS + 1
	_refresh()


func _count() -> int:
	return TIME_STEPS.size() if _page == PAGE_TIME else _places.size()


func _apply() -> void:
	if _page == PAGE_TIME:
		Game.time_override = TIME_STEPS[_sel[_page]]
		_refresh()
		return
	var place := _places[_sel[_page]]
	var vp: Array = WORLD.viewpoints()[place]
	var player: Node3D = get_parent().player()
	player.global_position = (vp[0] as Vector3) - Vector3(0, 1.6, 0)
	player.look_at_point(vp[1] as Vector3)
	travelled.emit(place)


## What a climb through the list shows: the page's rows from the scroll position.
func _refresh() -> void:
	for row in _body.get_children():
		_body.remove_child(row)
		row.queue_free()
	for i in _tabs.size():
		_tabs[i].add_theme_color_override("font_color", UiStyle.BORDER if i == _page else UiStyle.MUTED)
	_hints.text = "%s    %d / %d" % [tr("UI_ADMIN_KEYS"), int(_sel[_page]) + 1, _count()]
	var first: int = _scroll[_page]
	var last: int = mini(first + ROWS, _count())
	for i in range(first, last):
		_body.add_child(_row(i, i == _sel[_page]))
	_center.call_deferred()


func _row(i: int, selected: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var mark := UiStyle.label(">" if selected else " ", 18, UiStyle.BORDER)
	row.add_child(mark)
	var name := ""
	var value := ""
	if _page == PAGE_TIME:
		name = tr(TIME_KEYS[i])
		value = tr("UI_ADMIN_NORMAL_VALUE") if TIME_STEPS[i] < 0.0 else "%0.2f" % TIME_STEPS[i]
	else:
		var place: String = _places[i]
		var key: String = PLACE_KEYS.get(place, "")
		name = "%s  (%s)" % [tr(key) if key != "" else place, place]
	var label := UiStyle.label(name, 20, UiStyle.BORDER if selected else UiStyle.TEXT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	if value != "":
		row.add_child(UiStyle.label(value, 18, UiStyle.MUTED))
	return row


func _center() -> void:
	var view := get_viewport().get_visible_rect().size
	_card.position = Vector2(maxf(24.0, (view.x - _card.size.x) * 0.5), maxf(24.0, (view.y - _card.size.y) * 0.5))


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _body:
		_title.text = tr("UI_ADMIN_TITLE")
		_hints.text = tr("UI_ADMIN_KEYS")
		_tabs[0].text = tr("UI_ADMIN_TIME")
		_tabs[1].text = tr("UI_ADMIN_PLACES")
		_refresh()
