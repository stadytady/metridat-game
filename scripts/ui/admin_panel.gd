class_name AdminPanel
extends CanvasLayer
## The developer menu on the tilde key: the hour of the day, and a jump to any of
## the viewpoints the screenshots use. Deliberately not in the controls legend and
## not translated like a player-facing panel — it is a tool, not a feature.

signal travelled(place: String)

const WORLD := preload("res://scripts/world/world.gd")

const PAGE_TIME := 0
const PAGE_PLACES := 1
const PAGE_SCENE := 2
## Actions that move the story rather than the camera: [id, translation key].
const ACTIONS := [
	["sleep", "UI_ADMIN_SLEEP_AT"],
	["dream", "UI_ADMIN_ENTER_DREAM"],
	["wake", "UI_ADMIN_WAKE"],
	["lamps", "UI_ADMIN_LAMPS"],
]
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
var _sel := [0, 0, 0]
var _scroll := [0, 0, 0]
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
	for i in 3:
		var l := UiStyle.label(tr(_tab_key(i)), 19, UiStyle.MUTED)
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


func _tab_key(page: int) -> String:
	match page:
		PAGE_TIME:
			return "UI_ADMIN_TIME"
		PAGE_PLACES:
			return "UI_ADMIN_PLACES"
		_:
			return "UI_ADMIN_SCENE"


func _rule() -> Control:
	var line := ColorRect.new()
	line.color = Color(0.55, 0.4, 0.2, 0.7)
	line.custom_minimum_size = Vector2(0, 1)
	return line


func open() -> void:
	visible = true
	_refresh()
	Game.ui_blocking = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	visible = false
	Game.ui_blocking = false
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
	if event.is_action_pressed(&"move_forward"):
		_move(-1)
	elif event.is_action_pressed(&"move_back"):
		_move(1)
	elif event.is_action_pressed(&"move_left"):
		_page = maxi(_page - 1, PAGE_TIME)
		_refresh()
	elif event.is_action_pressed(&"move_right"):
		_page = mini(_page + 1, PAGE_SCENE)
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
	match _page:
		PAGE_TIME:
			return TIME_STEPS.size()
		PAGE_PLACES:
			return _places.size()
		_:
			return ACTIONS.size()


func _apply() -> void:
	if _page == PAGE_TIME:
		Game.time_override = TIME_STEPS[_sel[_page]]
		_refresh()
		return
	if _page == PAGE_SCENE:
		_run(ACTIONS[_sel[_page]][0])
		return
	var place := _places[_sel[_page]]
	var vp: Array = WORLD.viewpoints()[place]
	var player: Node3D = get_parent().player()
	player.global_position = (vp[0] as Vector3) - Vector3(0, 1.6, 0)
	player.look_at_point(vp[1] as Vector3)
	travelled.emit(place)


## Story leaps: the dream and back, and the lamps it needs.
func _run(action: String) -> void:
	var main := get_parent()
	match action:
		"lamps":
			for lamp: Lamp in Game.lamps:
				if not lamp.lit:
					lamp.interact()
		"sleep":
			var spot: Node3D = main.world.find_child("SleepSpot", true, false)
			if spot == null:
				push_warning("admin: no sleeping place in the abaton")
				return
			main.player().global_position = spot.global_position + Vector3(0, 0.1, 0)
			for lamp: Lamp in Game.lamps:
				if not lamp.lit:
					lamp.interact()
			close()
			Game.dream_requested.emit()
		"dream":
			close()
			Game.dream_requested.emit()
		"wake":
			var dream: Node = main.world.get_node_or_null("Dream")
			if dream == null or not Game.dreaming:
				return
			close()
			dream.wake()


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
	elif _page == PAGE_SCENE:
		name = tr(ACTIONS[i][1])
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
		for i in _tabs.size():
			_tabs[i].text = tr(_tab_key(i))
		_refresh()
