class_name KeysBar
extends Control
## The controls legend under the view: a key cap and what it does, repeated, in one
## quiet strip. Small caps on the keys, plain words beside them, dots between the
## pairs — a legend, not a line of running text.

## [key cap, translation key]. The caps read the same in every language.
const ENTRIES := [
	["WASD", "UI_ACTION_WALK"],
	["SHIFT", "UI_ACTION_RUN"],
	["SPACE", "UI_ACTION_JUMP"],
	["MOUSE", "UI_ACTION_LOOK"],
	["E", "UI_ACTION_USE"],
	["J", "UI_ACTION_JOURNAL"],
	["TAB", "UI_ACTION_GOALS"],
	["ESC", "UI_ACTION_PAUSE"],
]
const CAP_PAD := Vector2(9, 3)

var _actions: Array[Label] = []


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
func _pair(cap: String, action_key: String) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	var cap_panel := PanelContainer.new()
	cap_panel.add_theme_stylebox_override("panel", _cap_style())
	cap_panel.add_child(UiStyle.label(cap, 17, UiStyle.BORDER))
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
