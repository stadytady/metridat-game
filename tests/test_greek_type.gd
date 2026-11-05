extends "res://tests/test_case.gd"
## The carved name: every letter has strokes, every stroke stays inside the unit
## box, and the width adds up so the inscription stays centred.

const G := preload("res://scripts/ui/greek_type.gd")
const T := preload("res://scripts/ui/greek_title.gd")


func test_every_letter_of_the_name_is_cut() -> void:
	var absent := G.missing(T.WORD)
	check(absent == "", "no glyph for: %s" % absent)
	for ch: String in G.GLYPHS:
		var strokes: Array = G.GLYPHS[ch]
		if ch == " ":
			check(strokes.is_empty(), "the space is drawn")
			continue
		check(strokes.size() >= 1, "%s has no strokes" % ch)
		for s: Array in strokes:
			check(s.size() >= 2, "%s has a stroke of %d points" % [ch, s.size()])
			for p: Vector2 in s:
				check(p.x >= -0.01 and p.x <= G.BOX + 0.01, "%s leaves its box at %s" % [ch, p])
				check(p.y >= -0.01 and p.y <= 1.01, "%s leaves its box at %s" % [ch, p])


func test_width_adds_up() -> void:
	check(is_equal_approx(G.width_of("ΠΑ", 100.0, 20.0), 2.0 * G.WIDE * 100.0 + 20.0), "two letters")
	check(is_equal_approx(G.width_of("", 100.0, 20.0), 0.0), "an empty word has width")


func test_missing_reports_unknown_letters() -> void:
	check(G.missing("ΠΑΝΤΑ") == "", "ΠΑΝΤΑ reported %s" % G.missing("ΠΑΝΤΑ"))
	check(G.missing("ΠΑΝΤΑQ") == "Q", "an unknown letter was not reported")
