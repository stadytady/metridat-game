class_name GreekType
extends RefCounted
## Square Greek capitals, drawn from a 5x7 bitmap so the title can be cut in stone
## the way the city cut its own name. No font file: the glyphs are the asset, and
## they stay sharp at any size because they are rectangles.

const W := 5
const H := 7

## Letters used by the inscriptions in the game; anything missing is a bug the test
## catches, not a fallback.
const GLYPHS := {
	"Α": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"Β": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
	"Γ": ["#####", "#....", "#....", "#....", "#....", "#....", "#...."],
	"Δ": ["..#..", ".#.#.", ".#.#.", "#...#", "#...#", "#...#", "#####"],
	"Ε": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
	"Η": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"Θ": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", ".###."],
	"Ι": ["..#..", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
	"Κ": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
	"Λ": ["..#..", ".#.#.", ".#.#.", "#...#", "#...#", "#...#", "#...#"],
	"Μ": ["#...#", "##.##", "#.#.#", "#...#", "#...#", "#...#", "#...#"],
	"Ν": ["#...#", "##..#", "##..#", "#.#.#", "#..##", "#..##", "#...#"],
	"Ξ": ["#####", ".....", ".....", "#####", ".....", ".....", "#####"],
	"Ο": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"Π": ["#####", "#...#", "#...#", "#...#", "#...#", "#...#", "#...#"],
	"Ρ": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
	"Σ": ["#####", "#....", "#....", ".###.", "....#", "....#", "#####"],
	"Τ": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
	"Υ": ["#...#", "#...#", ".###.", "..#..", "..#..", "..#..", "..#.."],
	"Φ": ["..#..", ".###.", "#.#.#", "#.#.#", ".###.", "..#..", "..#.."],
	"Χ": ["#...#", "#...#", ".###.", "..#..", ".###.", "#...#", "#...#"],
	"Ψ": ["#.#.#", "#.#.#", "#.#.#", ".###.", "..#..", "..#..", "..#.."],
	"Ω": [".###.", "#...#", "#...#", "#...#", "#...#", ".#.#.", "#...#"],
	" ": [".....", ".....", ".....", ".....", ".....", ".....", "....."],
}


## Letters of `word` that have no glyph, so a typo cannot ship as a silent gap.
static func missing(word: String) -> String:
	var out := ""
	for i in word.length():
		var ch := word[i].to_upper()
		if not GLYPHS.has(ch) and not out.contains(ch):
			out += ch
	return out


## Width of a word at this cell size, letter spacing included.
static func width_of(word: String, cell: float, gap: float) -> float:
	if word.is_empty():
		return 0.0
	return word.length() * (W * cell) + (word.length() - 1) * gap


## Draws the word with its top-left corner at `at`. `shadow` pushes a dark copy
## behind it, the way carved letters read in low sun.
static func draw(ci: CanvasItem, word: String, at: Vector2, cell: float, gap: float,
		color: Color, shadow := 0.0, shadow_color := Color(0.05, 0.03, 0.02, 0.9)) -> void:
	var x := at.x
	for i in word.length():
		var rows: Array = GLYPHS.get(word[i].to_upper(), [])
		for y in rows.size():
			var row: String = rows[y]
			for gx in row.length():
				if row[gx] != "#":
					continue
				var r := Rect2(x + gx * cell, at.y + y * cell, cell, cell)
				if shadow > 0.0:
					ci.draw_rect(Rect2(r.position + Vector2(shadow, shadow), r.size), shadow_color)
				ci.draw_rect(r, color)
		x += W * cell + gap
