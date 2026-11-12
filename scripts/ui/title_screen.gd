extends CanvasLayer
## Start screen over the live view from the hill: the name as one word, wide
## spaced like a carved inscription, between two bands of Greek key (meander),
## and START. The world keeps moving behind it (sea, ships); the HUD and the
## player wait until START. No cursor: any click, Enter, Space or E starts.
## Skipped in automation (shots, walkthrough, trailer).

signal started
## START on a saved walk: Main puts it back instead of running the prologue.
signal continued

const TITLE := "PANTICAPAEUM"
const GOLD := Color("#d9a75a")
const SHADOW := Color(0.05, 0.03, 0.02, 0.9)

var _root: Control
var _start: Button
var _new: Button
## A saved walk is waiting: START reads "Continue", and "New walk" starts over.
var has_save := false
## Which save "New walk" forgets (tests point it elsewhere, not at the player's).
var save_path := SaveGame.PATH
var _bands: Array[Control] = []
var _fading := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 3
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	# darken towards the centre band so the title reads over a bright sky
	var shade := TextureRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0.15), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.15)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	_root.add_child(shade)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 26)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(col)
	col.add_child(_band())
	# the name itself in Greek capitals, cut rather than typed
	col.add_child(GreekTitle.new())
	var latin := Label.new()
	latin.text = "PANTICAPAEUM"
	latin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	latin.add_theme_font_size_override("font_size", 18)
	latin.add_theme_color_override("font_color", Color(UiStyle.MUTED, 0.75))
	col.add_child(latin)
	col.add_child(_band())
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 40)
	col.add_child(gap)
	_start = UiStyle.button("UI_START")
	_start.custom_minimum_size = Vector2(320, 64)
	_start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_start.add_theme_font_size_override("font_size", 32)
	_start.pressed.connect(start)
	_start.focus_mode = Control.FOCUS_ALL
	col.add_child(_start)
	_new = UiStyle.button("UI_NEW_GAME")
	_new.custom_minimum_size = Vector2(320, 48)
	_new.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_new.add_theme_font_size_override("font_size", 24)
	_new.pressed.connect(start_over)
	_new.focus_mode = Control.FOCUS_ALL
	_new.visible = false
	col.add_child(_new)
	_root.visible = false


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
	var n := int(w / (unit * px))
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
	_start.text = "UI_CONTINUE" if saved else "UI_START"
	_new.visible = saved
	_root.visible = true
	_root.modulate.a = 1.0
	_fading = false
	Game.ui_blocking = true
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN  # a clean picture; the button shows as selected
	_start.grab_focus()


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
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and not (_new.visible and _new.get_global_rect().has_point((event as InputEventMouseButton).position))
	if click or event.is_action_pressed(&"interact") or event.is_action_pressed(&"jump") or event.is_action_pressed(&"ui_accept"):
		# a key on "New walk" (focused with the arrows) means it, not Continue
		if not click and _new.visible and _new.has_focus():
			start_over()
		else:
			start()
		get_viewport().set_input_as_handled()
