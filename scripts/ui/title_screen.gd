extends CanvasLayer
## Start screen over the live view from the hill: the name cut as an inscription
## between two bands of Greek key (meander), the name again in the player's
## language below, and a menu of words - start (or continue), a new walk, quit -
## the chosen one gold between two lozenges. On opening the bands run out from
## the middle, the letters are cut one by one, the menu comes up. The world keeps
## moving behind (sea, ships); the HUD and the player wait. The cursor shows only
## once the mouse moves; a click on empty space, Enter, Space or E takes the
## chosen item (START unless another is chosen).
## Skipped in automation (shots, walkthrough, trailer).

signal started
## START on a saved walk: Main puts it back instead of running the prologue.
signal continued

const GOLD := Color("#d9a75a")
const SHADOW := Color(0.05, 0.03, 0.02, 0.9)

var _root: Control
var _title: GreekTitle
var _sub: Label
var _menu: VBoxContainer
var _start: Button
var _new: Button
var _quit: Button
var _mark: Control
var _intro: Tween
## A saved walk is waiting: START reads "Continue", and "New walk" starts over.
var has_save := false
## Which save "New walk" forgets (tests point it elsewhere, not at the player's).
var save_path := SaveGame.PATH
var _bands: Array[Control] = []
var _fading := false
## How far the meander bands have run out from the middle (0..1), on opening.
var _band_grow := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 3
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	# the edges sink into shadow and a darker band lies behind the inscription,
	# so the gold reads over a bright sky without a box round it
	_root.add_child(_shade(GradientTexture2D.FILL_RADIAL, Vector2(0.5, 0.48), Vector2(1.05, 0.48),
			[0.0, 0.55, 1.0], [Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.25), Color(0, 0, 0, 0.75)]))
	_root.add_child(_shade(GradientTexture2D.FILL_LINEAR, Vector2(0, 0), Vector2(0, 1),
			[0.0, 0.42, 0.62, 1.0], [Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.5), Color(0, 0, 0, 0.5), Color(0, 0, 0, 0.0)]))

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(col)
	col.add_child(_band())
	# the name itself in Greek capitals, cut rather than typed
	_title = GreekTitle.new()
	col.add_child(_title)
	# under it, letter-spaced small capitals: the name in the player's language
	_sub = Label.new()
	_sub.text = "UI_TITLE_SUB"
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.font(_sub, 22)
	var spaced := FontVariation.new()
	spaced.base_font = _sub.get_theme_default_font()
	spaced.spacing_glyph = 6
	_sub.add_theme_font_override("font", spaced)
	_sub.add_theme_color_override("font_color", Color(GOLD, 0.85))
	_sub.add_theme_color_override("font_shadow_color", SHADOW)
	_sub.add_theme_constant_override("shadow_offset_x", 2)
	_sub.add_theme_constant_override("shadow_offset_y", 2)
	col.add_child(_sub)
	col.add_child(_band())
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 36)
	col.add_child(gap)
	# the menu: words, not boxes; the chosen one gold between two small lozenges
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 6)
	_menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_menu)
	_start = _item("UI_START", 34)
	_start.pressed.connect(start)
	_new = _item("UI_NEW_GAME", 26)
	_new.pressed.connect(start_over)
	_new.visible = false
	_quit = _item("UI_QUIT", 26)
	_quit.pressed.connect(func() -> void: get_tree().quit())
	# a browser tab is not quit from inside the page
	_quit.visible = not OS.has_feature("web")
	_mark = Control.new()
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mark.draw.connect(_draw_mark)
	_root.add_child(_mark)
	get_viewport().gui_focus_changed.connect(func(_c: Control) -> void: _mark.queue_redraw())
	# the build's number in the corner, so a playtester's notes say which one
	var ver := Label.new()
	ver.text = "v" + SessionLog.version()
	ver.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	UiStyle.font(ver, 18)
	ver.add_theme_color_override("font_color", Color(UiStyle.MUTED, 0.8))
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ver.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ver.offset_right = -24
	ver.offset_bottom = -16
	ver.name = "Version"
	_root.add_child(ver)
	_root.visible = false


## A full-screen shade: a gradient of black, for the vignette and the band.
func _shade(fill: int, from: Vector2, to: Vector2, offsets: Array, colors: Array) -> TextureRect:
	var t := TextureRect.new()
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = fill
	gt.fill_from = from
	gt.fill_to = to
	t.texture = gt
	t.stretch_mode = TextureRect.STRETCH_SCALE
	return t


## A menu item: a word in spaced capitals, no box; gold when chosen. Hovering
## chooses it, so one item is chosen, never two.
func _item(key: String, size: int) -> Button:
	var b := Button.new()
	b.flat = true
	# capitals throughout, whatever case the shared key has in the pause menu
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_label(b, key)
	b.focus_mode = Control.FOCUS_ALL
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiStyle.font(b, size)
	var spaced := FontVariation.new()
	spaced.base_font = b.get_theme_default_font()
	spaced.spacing_glyph = 3
	b.add_theme_font_override("font", spaced)
	var empty := StyleBoxEmpty.new()
	empty.set_content_margin_all(6)
	for state in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(state, empty)
	b.add_theme_color_override("font_color", Color(UiStyle.MUTED, 0.9))
	for state in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, GOLD)
	b.add_theme_color_override("font_outline_color", SHADOW)
	b.add_theme_constant_override("outline_size", 6)
	b.mouse_entered.connect(b.grab_focus)
	_menu.add_child(b)
	return b


## Sets a menu item's text from its key, in capitals; the key stays in meta.
func _label(b: Button, key: String) -> void:
	b.set_meta(&"key", key)
	b.text = tr(key).to_upper()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _menu != null:
		for b: Button in [_start, _new, _quit]:
			_label(b, String(b.get_meta(&"key")))


## Two small lozenges either side of the chosen item.
func _draw_mark() -> void:
	var f := get_viewport().gui_get_focus_owner()
	if f == null or not (f is Button) or f.get_parent() != _menu or _menu.modulate.a <= 0.01:
		return
	var r := f.get_global_rect()
	var y := r.get_center().y
	var s := 7.0
	for x: float in [r.position.x - 22.0, r.end.x + 22.0]:
		var c := Vector2(x, y)
		var pts := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)])
		_mark.draw_colored_polygon(pts, Color(GOLD, _menu.modulate.a))


## A band of Greek key, drawn in square pixels like the rest of the UI.
func _band() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(1100, 30)
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(_draw_meander.bind(c))
	_bands.append(c)
	return c


## One unit of a running meander on a 6x6 grid of 5 px cells: a hook that
## rises from a continuous bottom rail and spirals in. Units repeat with no
## gap, so the rail joins them into one unbroken line (a row of separate
## hooks reads as letters).
static func meander_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in 6:
		cells.append(Vector2i(x, 5))  # rail, runs on into the next unit
	for y in range(0, 5):
		cells.append(Vector2i(0, y))  # up from the rail
	for x in range(1, 5):
		cells.append(Vector2i(x, 0))  # across the top
	for y in range(1, 4):
		cells.append(Vector2i(4, y))  # down the right
	cells.append(Vector2i(3, 3))
	cells.append(Vector2i(2, 3))  # back left
	cells.append(Vector2i(2, 2))  # and up: the inner end
	return cells


func _draw_meander(c: Control) -> void:
	var px := 5.0
	var unit := 6  # cells per repeat; no gap, the rail runs through
	var w := c.size.x
	var rows := 6
	var top := (c.size.y - rows * px) / 2.0
	var cells := meander_cells()
	var n := int(int(w / (unit * px)) * _band_grow)
	var x0 := (w - n * unit * px) / 2.0
	for shadow in [true, false]:
		var off := Vector2(3, 3) if shadow else Vector2.ZERO
		var color := SHADOW if shadow else GOLD
		c.draw_rect(Rect2(Vector2(x0, top - 2 * px) + off, Vector2(n * unit * px, px)), color)
		c.draw_rect(Rect2(Vector2(x0, top + (rows + 1) * px) + off, Vector2(n * unit * px, px)), color)
		for i in n:
			for cell: Vector2i in cells:
				var p := Vector2(x0 + (i * unit + cell.x) * px, top + cell.y * px) + off
				c.draw_rect(Rect2(p, Vector2(px, px)), color)


func is_open() -> bool:
	return _root.visible


func open(saved := false) -> void:
	has_save = saved
	_label(_start, "UI_CONTINUE" if saved else "UI_START")
	_new.visible = saved
	_root.visible = true
	_root.modulate.a = 1.0
	_fading = false
	Game.ui_blocking = true
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN  # a clean picture; the mouse brings the cursor back
	_start.grab_focus()
	_play_intro()


## The bands run out from the middle, the letters are cut one by one, then the
## name below and the menu come up. The first key or click finishes it at once.
func _play_intro() -> void:
	if _intro != null:
		_intro.kill()
	_set_grow(0.0)
	_title.reveal = 0.0
	_sub.modulate.a = 0.0
	_menu.modulate.a = 0.0
	_intro = create_tween()
	_intro.tween_method(_set_grow, 0.0, 1.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_intro.tween_property(_title, "reveal", 1.0, 1.4)
	_intro.tween_property(_sub, "modulate:a", 1.0, 0.6)
	_intro.tween_property(_menu, "modulate:a", 1.0, 0.5)
	_intro.tween_callback(_mark.queue_redraw)


func _set_grow(v: float) -> void:
	_band_grow = v
	for b: Control in _bands:
		b.queue_redraw()


## Ends the opening at once: everything in place.
func finish_intro() -> void:
	if _intro != null and _intro.is_running():
		_intro.kill()
	_set_grow(1.0)
	_title.reveal = 1.0
	_sub.modulate.a = 1.0
	_menu.modulate.a = 1.0
	_mark.queue_redraw()


func intro_running() -> bool:
	return _intro != null and _intro.is_running()


## START: fade the screen out and hand the game to the player. The mouse is
## captured from inside the click, which browsers need for pointer lock.
func start() -> void:
	if not _root.visible or _fading:
		return
	_fading = true
	Game.ui_blocking = false
	Game.mark_ui_closed()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if has_save:
		continued.emit()
	else:
		started.emit()
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func() -> void:
		_root.visible = false
		_fading = false)


## "New walk": forget the saved one and start from the pier.
func start_over() -> void:
	if not _root.visible or _fading:
		return
	SaveGame.erase(save_path)
	has_save = false
	start()


func _input(event: InputEvent) -> void:
	# The title lives in the root viewport (not the world's), so it gets input.
	if not _root.visible or _fading:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var key: bool = event.is_action_pressed(&"interact") or event.is_action_pressed(&"jump") or event.is_action_pressed(&"ui_accept")
	if not (click or key):
		return
	get_viewport().set_input_as_handled()
	# the first press only finishes the opening
	if intro_running():
		finish_intro()
		return
	var item := _start
	if click:
		var at := (event as InputEventMouseButton).position
		for b: Button in [_new, _quit]:
			if b.visible and b.get_global_rect().has_point(at):
				item = b
	else:
		var f := get_viewport().gui_get_focus_owner()
		if f == _new or f == _quit:
			item = f
	if item == _new:
		start_over()
	elif item == _quit:
		get_tree().quit()
	else:
		start()
