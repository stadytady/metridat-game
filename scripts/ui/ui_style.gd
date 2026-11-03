class_name UiStyle
extends RefCounted
## Late-90s console UI: flat dark panels, hard 2 px borders, no rounding,
## aliased text (see gui/theme/default_font_antialiasing in project.godot).

const BG := Color(0.07, 0.055, 0.04, 0.88)
const BORDER := Color("#c9953f")
const TEXT := Color("#e6d6b4")
const MUTED := Color("#a8977a")
const HISTORY := Color("#7aa39b")
const FICTION := Color("#d98b55")


static func panel() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.border_color = BORDER
	sb.set_border_width_all(2)
	sb.set_content_margin_all(20)
	sb.anti_aliasing = false
	return sb


static func label(text: String, size: int, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


static func button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 26)
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := panel()
		sb.set_content_margin_all(10)
		if state == "hover" or state == "focus":
			sb.bg_color = Color(0.25, 0.16, 0.08, 0.95)
		elif state == "pressed":
			# Toggle buttons (language) must show which one is on.
			sb.bg_color = Color("#7a4a16")
			sb.border_color = Color("#f2c48c")
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_stylebox_override("hover_pressed", b.get_theme_stylebox("pressed"))
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	return b
