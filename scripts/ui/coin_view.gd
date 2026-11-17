class_name CoinView
extends Control
## The stater being struck, drawn flat: a gold blank, a little out of round as
## a hand-cut blank is, and on it the reverse of Panticapaeum's gold - a spear
## over an ear of grain and the letters ΠΑΝ (the griffin that stands on them on
## the real coin is left to the coin_stater find). A true blow drives it in
## clean; a glancing blow leaves a faint second image, a miss slides it off
## the middle (MintGame.offset/doubled). One coin, one blow: -1 is a blank
## still waiting on the anvil.

const GOLD := Color("#d9a75a")
const DEEP := Color("#6e4a1c")
const RADIUS := 78.0

var grade := -1
var blank := 0


func _ready() -> void:
	custom_minimum_size = Vector2(RADIUS * 2.0 + 40.0, RADIUS * 2.0 + 40.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_blow(g: int, index: int) -> void:
	grade = g
	blank = index
	queue_redraw()


## The blank's outline: a twelve-sided circle pushed in and out a little, the
## same every time (the blank does not change between blows).
static func blank_outline(center: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		var wobble := 1.0 + 0.035 * sin(a * 3.0 + 0.7) + 0.02 * sin(a * 5.0)
		pts.append(center + Vector2.from_angle(a) * r * wobble)
	return pts


func _draw() -> void:
	var c := size / 2.0
	var outline := blank_outline(c, RADIUS)
	draw_colored_polygon(outline, GOLD.darkened(0.12))
	var rim := outline.duplicate()
	rim.append(outline[0])
	draw_polyline(rim, GOLD.lightened(0.25), 3.0)
	if grade < 0:
		return
	var off := MintGame.offset(grade, blank) * RADIUS
	if MintGame.doubled(grade):
		_design(c + off + Vector2.from_angle(0.4 + float(blank) * 2.2) * RADIUS * 0.08, Color(DEEP, 0.35))
	_design(c + off, DEEP)


func _design(at: Vector2, ink: Color) -> void:
	var r := RADIUS
	# the ear of grain, upright under the spear
	var stalk_a := at + Vector2(0, r * 0.42)
	var stalk_b := at + Vector2(0, -r * 0.05)
	draw_line(stalk_a, stalk_b, ink, 4.0)
	for i in 5:
		var y := r * (0.32 - 0.08 * float(i))
		for side: float in [-1.0, 1.0]:
			draw_line(at + Vector2(0, y), at + Vector2(side * r * 0.11, y - r * 0.09), ink, 3.0)
	# the spear across it, point to the right
	var sa := at + Vector2(-r * 0.62, r * 0.02)
	var sb := at + Vector2(r * 0.5, -r * 0.12)
	draw_line(sa, sb, ink, 4.0)
	var dir := (sb - sa).normalized()
	var nrm := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([sb + dir * r * 0.16, sb + nrm * r * 0.05, sb - nrm * r * 0.05]), ink)
	# ΠΑΝ above, as on the coin
	var h := r * 0.3
	var gap := h * 0.18
	var w := GreekType.width_of("ΠΑΝ", h, gap)
	GreekType.draw(self, "ΠΑΝ", at + Vector2(-w / 2.0, -r * 0.62), h, gap, ink, 3.0, 0.0, Color(0, 0, 0, 0))
