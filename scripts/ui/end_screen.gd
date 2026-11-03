extends CanvasLayer
## THE END over black, then the credits rising, then the keys: Enter (or E,
## or a click) wakes the dreamer in the abaton, Esc quits. Holds the input
## while shown.

signal woke

const GOLD := Color("#d9a75a")
const CREDITS := ["UI_CREDITS_1", "UI_CREDITS_2", "UI_CREDITS_3", "UI_CREDITS_4", "UI_CREDITS_5"]
const SCROLL_SECONDS := 9.0

var finished := false
var _tw: Tween
var _bg: ColorRect
var _end: Label
var _credits: VBoxContainer
var _keys: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
	_bg = ColorRect.new()
	_bg.color = Color.BLACK
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)
	_end = UiStyle.label("UI_THE_END", 96, GOLD)
	_end.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end.position = Vector2(0, 420)
	_end.size = Vector2(1920, 120)
	_end.modulate.a = 0.0
	add_child(_end)
	_credits = VBoxContainer.new()
	_credits.add_theme_constant_override("separation", 26)
	_credits.position = Vector2(0, 1100)
	_credits.size = Vector2(1920, 400)
	for key: String in CREDITS:
		var l := UiStyle.label(key, 30)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(1920, 0)
		_credits.add_child(l)
	add_child(_credits)
	_keys = UiStyle.label("UI_END_KEYS", 24, UiStyle.MUTED)
	_keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_keys.position = Vector2(0, 980)
	_keys.size = Vector2(1920, 40)
	_keys.modulate.a = 0.0
	add_child(_keys)


func play() -> void:
	Game.ui_blocking = true
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_tw = create_tween()
	_tw.tween_property(_end, "modulate:a", 1.0, 1.5)
	_tw.tween_interval(1.5)
	_tw.tween_property(_end, "position:y", 160.0, 1.5).set_trans(Tween.TRANS_SINE)
	_tw.tween_property(_credits, "position:y", 380.0, SCROLL_SECONDS)
	_tw.tween_property(_keys, "modulate:a", 1.0, 0.8)
	_tw.tween_callback(func() -> void: finished = true)


## Skips the wait (tests, and anyone pressing a key early).
func skip_to_keys() -> void:
	if _tw:
		_tw.kill()
	_end.modulate.a = 1.0
	_end.position.y = 160.0
	_credits.position.y = 380.0
	_keys.modulate.a = 1.0
	finished = true


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		get_tree().quit()
		return
	var go: bool = event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"interact") \
			or (event is InputEventMouseButton and event.pressed)
	if not go:
		return
	get_viewport().set_input_as_handled()
	if not finished:
		skip_to_keys()
	else:
		woke.emit()
