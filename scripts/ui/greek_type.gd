class_name GreekType
extends RefCounted
## A Greek display face drawn as strokes, in the manner of the carved letters the
## city would have cut: thin even lines, sharp corners, wide open letterforms.
## Every glyph is a list of polylines in a unit box — x from 0 to WIDE, y from 0
## (cap line) to 1 (baseline) — so the letters scale to any height and stay crisp.

const WIDE := 0.62

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
	"Ι": [[Vector2(0.31, 0), Vector2(0.31, 1)]],
	"Κ": [[Vector2(0, 0), Vector2(0, 1)], [Vector2(0.6, 0), Vector2(0.02, 0.52)], [Vector2(0.2, 0.34), Vector2(0.6, 1)]],
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


## Width of a word at this cap height, letter spacing included.
static func width_of(word: String, height: float, gap: float) -> float:
	if word.is_empty():
		return 0.0
	return word.length() * WIDE * height + (word.length() - 1) * gap


## Draws the word with its top-left corner at `at`. `stroke` is the line weight in
## pixels; `shadow` pushes a dark copy behind it, the way carved letters read in
## low sun.
static func draw(ci: CanvasItem, word: String, at: Vector2, height: float, gap: float,
		color: Color, stroke: float, shadow := 0.0, shadow_color := Color(0.05, 0.03, 0.02, 0.9)) -> void:
	var x := at.x
	for i in word.length():
		var strokes: Array = GLYPHS.get(word[i].to_upper(), [])
		for s: Array in strokes:
			var pts := PackedVector2Array()
			for p: Vector2 in s:
				pts.append(Vector2(x + p.x * height, at.y + p.y * height))
			if pts.size() < 2:
				continue
			if shadow > 0.0:
				var sh := PackedVector2Array()
				for p: Vector2 in pts:
					sh.append(p + Vector2(shadow, shadow))
				ci.draw_polyline(sh, shadow_color, stroke, false)
			ci.draw_polyline(pts, color, stroke, false)
		x += WIDE * height + gap
