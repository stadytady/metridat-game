class_name Palette
extends RefCounted

const BG := Color("#14161a")
const TEXT := Color("#d8dde6")
const MUTED := Color("#8a93a3")
const HOVER := Color("#ffffff")
const HIGHLIGHT := Color(1, 1, 1, 0.35)
## Index = cell color. 0 is the goal state, so it is the quietest one.
## Colors differ in lightness, not only hue, so they stay distinct for color-blind players.
const CELLS: Array[Color] = [
	Color("#2a2f38"),
	Color("#f2a541"),
	Color("#3fb6a8"),
	Color("#e2557a"),
	Color("#8f7cf0"),
]


static func glyph_color(cell: int) -> Color:
	return MUTED if cell == 0 else BG
