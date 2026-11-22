class_name GreekType
extends RefCounted
## A Greek display face drawn as strokes, in the manner of the carved letters the
## city would have cut: thin even lines, sharp corners, wide open letterforms.
## Every glyph is a list of polylines in a box `BOX` wide, y from 0 (cap line) to
## 1 (baseline); `WIDE` is the width the box is stretched to when drawn, so the
## face can be made broader without touching the glyph data.

## Coordinate space the glyphs are drawn in.
const BOX := 0.62
## Advance width of one letter, as a fraction of the cap height.
const WIDE := 0.78
## Side bearing each letter carries, as a fraction of the cap height.
const BEARING := 0.12

## Glyphs used by the inscriptions in the game. A letter listed here with no
## strokes is a bug the test catches, not something to paper over.
const GLYPHS := {
	"Α": [[Vector2(0, 1), Vector2(0.31, 0), Vector2(0.62, 1)], [Vector2(0.13, 0.62), Vector2(0.49, 0.62)]],
	"Β": [[Vector2(0, 1), Vector2(0, 0), Vector2(0.38, 0), Vector2(0.52, 0.14), Vector2(0.52, 0.36), Vector2(0.38, 0.5), Vector2(0, 0.5)],
		[Vector2(0.38, 0.5), Vector2(0.56, 0.62), Vector2(0.56, 0.88), Vector2(0.42, 1), Vector2(0, 1)]],
	"Γ": [[Vector2(0, 1), Vector2(0, 0), Vector2(0.62, 0)]],
	"Δ": [[Vector2(0, 1), Vector2(0.31, 0), Vector2(0.62, 1), Vector2(0, 1)]],
	"Ε": [[Vector2(0.62, 0), Vector2(0, 0), Vector2(0, 1), Vector2(0.62, 1)], [Vector2(0, 0.5), Vector2(0.44, 0.5)]],
	"Η": [[Vector2(0, 0), Vector2(0, 1)], [Vector2(0.62, 0), Vector2(0.62, 1)], [Vector2(0, 0.5), Vector2(0.62, 0.5)]],
	"Θ": [[Vector2(0.18, 0), Vector2(0.44, 0), Vector2(0.62, 0.18), Vector2(0.62, 0.82), Vector2(0.44, 1),
			Vector2(0.18, 1), Vector2(0, 0.82), Vector2(0, 0.18), Vector2(0.18, 0)],
		[Vector2(0, 0.5), Vector2(0.62, 0.5)]],
	"Ι": [[Vector2(0.2, 0), Vector2(0.42, 0)], [Vector2(0.31, 0), Vector2(0.31, 1)], [Vector2(0.2, 1), Vector2(0.42, 1)]],
	"Κ": [[Vector2(0, 0), Vector2(0, 1)], [Vector2(0.6, 0), Vector2(0.0, 0.44)], [Vector2(0.0, 0.44), Vector2(0.6, 1)]],
	"Λ": [[Vector2(0, 1), Vector2(0.31, 0), Vector2(0.62, 1)]],
	"Μ": [[Vector2(0, 1), Vector2(0, 0), Vector2(0.31, 0.62), Vector2(0.62, 0), Vector2(0.62, 1)]],
	"Ν": [[Vector2(0, 1), Vector2(0, 0), Vector2(0.62, 1), Vector2(0.62, 0)]],
	"Ξ": [[Vector2(0, 0), Vector2(0.62, 0)], [Vector2(0.08, 0.5), Vector2(0.54, 0.5)], [Vector2(0, 1), Vector2(0.62, 1)]],
	"Ο": [[Vector2(0.18, 0), Vector2(0.44, 0), Vector2(0.62, 0.18), Vector2(0.62, 0.82), Vector2(0.44, 1),
			Vector2(0.18, 1), Vector2(0, 0.82), Vector2(0, 0.18), Vector2(0.18, 0)]],
	"Π": [[Vector2(0, 1), Vector2(0, 0), Vector2(0.62, 0), Vector2(0.62, 1)]],
	"Ρ": [[Vector2(0, 1), Vector2(0, 0), Vector2(0.42, 0), Vector2(0.6, 0.16), Vector2(0.6, 0.36),
			Vector2(0.42, 0.52), Vector2(0, 0.52)]],
	"Σ": [[Vector2(0.62, 0), Vector2(0, 0), Vector2(0.34, 0.5), Vector2(0, 1), Vector2(0.62, 1)]],
	"Τ": [[Vector2(0, 0), Vector2(0.62, 0)], [Vector2(0.31, 0), Vector2(0.31, 1)]],
	"Υ": [[Vector2(0, 0), Vector2(0.31, 0.48), Vector2(0.62, 0)], [Vector2(0.31, 0.48), Vector2(0.31, 1)]],
	"Φ": [[Vector2(0.31, 0), Vector2(0.31, 1)], [Vector2(0.18, 0.2), Vector2(0.44, 0.2), Vector2(0.56, 0.32),
			Vector2(0.56, 0.66), Vector2(0.44, 0.78), Vector2(0.18, 0.78), Vector2(0.06, 0.66), Vector2(0.06, 0.32),
			Vector2(0.18, 0.2)]],
	"Χ": [[Vector2(0, 0), Vector2(0.62, 1)], [Vector2(0.62, 0), Vector2(0, 1)]],
	"Ψ": [[Vector2(0.31, 0.5), Vector2(0.31, 1)], [Vector2(0, 0), Vector2(0, 0.42), Vector2(0.62, 0.42),
			Vector2(0.62, 0)]],
	"Ω": [[Vector2(0, 1), Vector2(0.16, 0.82), Vector2(0.16, 0.2), Vector2(0.3, 0), Vector2(0.32, 0),
			Vector2(0.46, 0.2), Vector2(0.46, 0.82), Vector2(0.62, 1)]],
	" ": [],
}


## Letters of `word` that have no glyph, so a typo cannot ship as a silent gap.
static func missing(word: String) -> String:
	var out := ""
	for i in word.length():
		var ch := word[i].to_upper()
		if not GLYPHS.has(ch) and not out.contains(ch):
			out += ch
	return out


## Where a glyph's ink starts and ends in its box (x, in box units). An iota is
## drawn in the middle of its box: measuring only the right edge left a hole
## before every iota (ΠΑΝΤ ΙΚΑΠΑ ΙΟΝ), so the ink is set from its left edge.
static func glyph_span(ch: String) -> Vector2:
	var lo := INF
	var hi := -INF
	for s: Array in GLYPHS.get(ch.to_upper(), []):
		for p: Vector2 in s:
			lo = minf(lo, p.x)
			hi = maxf(hi, p.x)
	return Vector2(0.0, 0.0) if lo == INF else Vector2(lo, hi)


## The width a glyph's ink covers, so narrow letters take less room than wide
## ones: an even step for every letter is what made the first title look crooked.
static func glyph_width(ch: String) -> float:
	var span := glyph_span(ch)
	return (span.y - span.x) / BOX * WIDE


## One letter's step, side bearings included.
static func advance(ch: String, height: float) -> float:
	return (glyph_width(ch) + BEARING) * height


## Width of a word at this cap height, letter spacing included.
static func width_of(word: String, height: float, gap: float) -> float:
	var w := 0.0
	for i in word.length():
		w += advance(word[i], height)
		if i > 0:
			w += gap
	return w


## Where each letter's ink sits along the word, from `x0`: Vector2(left, right).
## Every gap between two letters is then BEARING * height + gap, whatever the
## letters - the test holds the setting to that.
static func ink_spans(word: String, height: float, gap: float, x0 := 0.0) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var x := x0
	for i in word.length():
		var ch := word[i].to_upper()
		var left := x + BEARING * height * 0.5
		out.append(Vector2(left, left + glyph_width(ch) * height))
		x += advance(ch, height) + gap
	return out


## Draws the word with its top-left corner at `at`. `stroke` is the line weight in
## pixels; `shadow` pushes a dark copy behind it, the way carved letters read in
## low sun, and `light` a pale edge up and left, the lit lip of the cut. `serif`
## (a fraction of the cap height) adds the small flared feet that letter cutters
## of the 4th century left on the ends of their strokes, at cap line and base.
## `count` draws only the first letters (an inscription appearing).
static func draw(ci: CanvasItem, word: String, at: Vector2, height: float, gap: float,
		color: Color, stroke: float, shadow := 0.0, shadow_color := Color(0.05, 0.03, 0.02, 0.9),
		serif := 0.0, light := Color(0, 0, 0, 0), count := -1) -> void:
	var spans := ink_spans(word, height, gap, at.x)
	var n := word.length() if count < 0 else mini(count, word.length())
	for pass_i in 3:
		# shadow under, then the lit lip, then the letter itself
		var off := Vector2(shadow, shadow) if pass_i == 0 else (Vector2(-1, -1) * maxf(1.0, stroke * 0.18) if pass_i == 1 else Vector2.ZERO)
		var col := shadow_color if pass_i == 0 else (light if pass_i == 1 else color)
		if (pass_i == 0 and shadow <= 0.0) or (pass_i == 1 and light.a <= 0.0):
			continue
		var w := stroke if pass_i != 1 else stroke * 0.6
		for i in n:
			var ch := word[i].to_upper()
			var left: float = spans[i].x - glyph_span(ch).x / BOX * WIDE * height
			for s: Array in GLYPHS.get(ch, []):
				var pts := PackedVector2Array()
				for p: Vector2 in s:
					pts.append(Vector2(left + p.x / BOX * WIDE * height, at.y + p.y * height) + off)
				if pts.size() < 2:
					continue
				ci.draw_polyline(pts, col, w, false)
				# square off the corners so the joints do not thin out
				for p: Vector2 in pts:
					ci.draw_rect(Rect2(p - Vector2(w, w) * 0.5, Vector2(w, w)), col)
				if serif > 0.0:
					for e: Vector2 in [s[0], s[-1]]:
						if e.y <= 0.02 or e.y >= 0.98:
							var q := Vector2(left + e.x / BOX * WIDE * height, at.y + e.y * height) + off
							var half := serif * height * 0.5
							ci.draw_rect(Rect2(q - Vector2(half, w * 0.5), Vector2(half * 2.0, w)), col)
