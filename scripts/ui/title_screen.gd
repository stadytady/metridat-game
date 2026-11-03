extends CanvasLayer
## Opening card inspired by painted Greek pottery and temple friezes.

const BLUE := Color("#173f5f")
const CLAY := Color("#b55332")
const OCHRE := Color("#d8ad62")
const PAPER := Color("#f0d6a5")

var _root: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _is_automation():
		queue_free()
		return
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_build()
	Game.ui_blocking = true
	# Main captures the mouse in its _ready, which runs after child layers.
	call_deferred("_show_cursor")


func _is_automation() -> bool:
	var args := OS.get_cmdline_user_args()
	return "--trailer" in args or "--benchmark" in args or "--shots" in args or "--walkthrough" in args


func _show_cursor() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build() -> void:
	var ground := ColorRect.new()
	ground.color = Color("#20150f")
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(ground)
	var field := ColorRect.new()
	field.color = CLAY
	field.set_anchors_preset(Control.PRESET_FULL_RECT)
	field.offset_left = 38
	field.offset_top = 38
	field.offset_right = -38
	field.offset_bottom = -38
	_root.add_child(field)
	_add_meander()

	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-370, -210)
	panel.size = Vector2(740, 420)
	panel.add_theme_constant_override("separation", 16)
	_root.add_child(panel)
	var crest := UiStyle.label("✦  ΠΑΝΤΙΚΑΠΑΙΟΝ  ✦", 26, PAPER)
	crest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crest.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	panel.add_child(crest)
	var title := UiStyle.label("TITLE_NAME", 54, PAPER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(title)
	var rule := ColorRect.new()
	rule.color = OCHRE
	rule.custom_minimum_size = Vector2(0, 3)
	panel.add_child(rule)
	var subtitle := UiStyle.label("TITLE_SUBTITLE", 24, Color("#f6dfb3"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 35)
	panel.add_child(spacer)
	var start := UiStyle.button("TITLE_ENTER")
	start.custom_minimum_size = Vector2(0, 62)
	start.pressed.connect(_enter_world)
	panel.add_child(start)
	var note := UiStyle.label("TITLE_NOTE", 18, Color("#f0cd8c"))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(note)
	start.grab_focus()


func _add_meander() -> void:
	# Repeating squared turns evoke a painted key pattern without a texture.
	for y: float in [54.0, 1026.0]:
		for x in range(64, 1900, 48):
			_meander_piece(Vector2(x, y), false)
	for x: float in [54.0, 1858.0]:
		for y in range(112, 1000, 48):
			_meander_piece(Vector2(x, y), true)


func _meander_piece(pos: Vector2, vertical: bool) -> void:
	var a := ColorRect.new()
	a.color = BLUE
	a.position = pos
	a.size = Vector2(34, 8) if not vertical else Vector2(8, 34)
	_root.add_child(a)
	var b := ColorRect.new()
	b.color = BLUE
	b.position = pos + (Vector2(26, 0) if not vertical else Vector2(0, 26))
	b.size = Vector2(8, 25) if not vertical else Vector2(25, 8)
	_root.add_child(b)


func _enter_world() -> void:
	Game.ui_blocking = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, 0.35)
	tween.tween_callback(queue_free)
