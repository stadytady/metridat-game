extends "res://tests/test_case.gd"
## The carved name: every letter has a glyph, every glyph is the same 5x7 cell, and
## the width adds up so the inscription stays centred.

const G := preload("res://scripts/ui/greek_type.gd")
const T := preload("res://scripts/ui/greek_title.gd")


func test_every_letter_of_the_name_is_cut() -> void:
	var absent := G.missing(T.WORD)
	check(absent == "", "no glyph for: %s" % absent)
	for ch: String in G.GLYPHS:
		var rows: Array = G.GLYPHS[ch]
		check(rows.size() == G.H, "%s has %d rows, not %d" % [ch, rows.size(), G.H])
		for r: String in rows:
			check(r.length() == G.W, "%s has a %d-wide row: %s" % [ch, r.length(), r])


func test_width_adds_up() -> void:
	check(is_equal_approx(G.width_of("ΠΑ", 10.0, 4.0), 2.0 * 5.0 * 10.0 + 4.0), "two letters")
	check(is_equal_approx(G.width_of("", 10.0, 4.0), 0.0), "an empty word has width")


func test_missing_reports_unknown_letters() -> void:
	check(G.missing("ΠΑΝΤΑ") == "", "ΠΑΝΤΑ reported %s" % G.missing("ΠΑΝΤΑ"))
	check(G.missing("ΠΑΝΤΑQ") == "Q", "an unknown letter was not reported")
