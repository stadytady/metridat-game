extends "res://tests/test_case.gd"
## The controls legend: every key cap has a word for it, and every word is in the
## string table, so the strip never shows a raw key.

const K := preload("res://scripts/ui/keys_bar.gd")
const CSV := "res://data/i18n/strings.csv"


func test_every_entry_has_a_cap_and_a_translated_action() -> void:
	var table := {}
	var f := FileAccess.open(CSV, FileAccess.READ)
	if f == null:
		check(false, "no " + CSV)
		return
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() >= 3 and row[0] != "":
			table[row[0]] = true
	for e: Array in K.ENTRIES:
		check(String(e[0]).strip_edges() != "", "an entry has no key cap")
		check(table.has(String(e[1])), "%s is missing from strings.csv" % e[1])


func test_the_legend_covers_the_controls_we_teach() -> void:
	var caps := []
	for e: Array in K.ENTRIES:
		caps.append(String(e[0]))
	for needed: String in ["WASD", "E", "J", "TAB", "ESC"]:
		check(caps.has(needed), "the legend forgot %s" % needed)
	check(K.ENTRIES.size() >= 6, "the legend shrank to %d entries" % K.ENTRIES.size())
