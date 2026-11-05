extends "res://tests/test_case.gd"
## The way-book's numbers: bars clamp, counters never read more than done.

const G := preload("res://scripts/ui/goals_panel.gd")


func test_bar_fraction() -> void:
	check(is_equal_approx(G.bar_fraction(0, 8), 0.0), "an untouched quest draws a bar")
	check(is_equal_approx(G.bar_fraction(4, 8), 0.5), "half a quest is not half a bar")
	check(is_equal_approx(G.bar_fraction(8, 8), 1.0), "a finished quest is not full")
	check(is_equal_approx(G.bar_fraction(9, 8), 1.0), "a bar runs past its end")
	check(is_equal_approx(G.bar_fraction(3, 0), 1.0), "an empty total is not full")


func test_progress_text() -> void:
	check(G.progress_text(3, 8) == "3 / 8", "3 of 8 reads %s" % G.progress_text(3, 8))
	check(G.progress_text(9, 8) == "8 / 8", "more than done reads %s" % G.progress_text(9, 8))
