class_name KeysBar
extends Control
## The controls legend under the view: a key cap and what it does, repeated, in one
## quiet strip. Small caps on the keys, plain words beside them, dots between the
## pairs — a legend, not a line of running text.

## [action, translation key]. The cap is the action's key, or its pad button
## while the pad is in hand (Keys.label): it reads the same in every language.
const ENTRIES := [
	[&"move", "UI_ACTION_WALK"],
	[&"sprint", "UI_ACTION_RUN"],
	[&"jump", "UI_ACTION_JUMP"],
	[&"look", "UI_ACTION_LOOK"],
	[&"interact", "UI_ACTION_USE"],
	[&"journal", "UI_ACTION_JOURNAL"],
	[&"goals", "UI_ACTION_GOALS"],
	[&"pause", "UI_ACTION_PAUSE"],
]
const CAP_PAD := Vector2(9, 3)

var _actions: Array[Label] = []
var _caps: Array[Label] = []


## The cap for an entry's action with these keys on this device.
static func cap(action: StringName, binds: Dictionary, pad: bool) -> String:
	if action == &"move":
		return Keys.move_label(binds, pad)
	if action == &"look":
		return Keys.PAD_NAMES[&"look"] if pad else "MOUSE"
	return Keys.label(action, binds, pad)


func _refresh_caps() -> void:
	for i in mini(_caps.size(), ENTRIES.size()):
		_caps[i].text = cap(ENTRIES[i][0], Game.key_binds, Game.pad)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# the control is wider than the strip: centre the strip inside it
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel", _strip_style())
	strip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(strip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	strip.add_child(row)
	for i in ENTRIES.size():
		if i > 0:
			row.add_child(_dot())
		row.add_child(_pair(ENTRIES[i][0], ENTRIES[i][1]))
	Game.device_changed.connect(_refresh_caps)
	Game.settings_changed.connect(_refresh_caps)


func _strip_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.03, 0.55)
	sb.border_color = Color(0.55, 0.4, 0.2, 0.35)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(8)
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.anti_aliasing = false
	return sb


func _dot() -> Label:
	return UiStyle.label("·", 18, Color(UiStyle.MUTED, 0.5))


## One key cap and the word for it.
func _pair(action_id: StringName, action_key: String) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	var cap_panel := PanelContainer.new()
	cap_panel.add_theme_stylebox_override("panel", _cap_style())
	var cap_label := UiStyle.label(cap(action_id, Game.key_binds, Game.pad), 17, UiStyle.BORDER)
	cap_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_caps.append(cap_label)
	cap_panel.add_child(cap_label)
	box.add_child(cap_panel)
	var action := UiStyle.label(tr(action_key), 18, UiStyle.MUTED)
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_actions.append(action)
	box.add_child(action)
	return box


func _cap_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.1, 0.07, 0.9)
	sb.border_color = Color(0.62, 0.45, 0.22, 0.9)
	sb.set_border_width_all(1)
	sb.content_margin_left = CAP_PAD.x
	sb.content_margin_right = CAP_PAD.x
	sb.content_margin_top = CAP_PAD.y
	sb.content_margin_bottom = CAP_PAD.y
	sb.anti_aliasing = false
	return sb


## The legend follows the language like every other label.
func _notification(what: int) -> void:
	if what != NOTIFICATION_TRANSLATION_CHANGED:
		return
	for i in mini(_actions.size(), ENTRIES.size()):
		_actions[i].text = tr(ENTRIES[i][1])
