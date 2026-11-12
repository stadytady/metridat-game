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
	var pads := []
	for e: Array in K.ENTRIES:
		caps.append(K.cap(e[0], {}, false))
		pads.append(K.cap(e[0], {}, true))
	for needed: String in ["WASD", "E", "J", "TAB", "ESC", "MOUSE"]:
		check(caps.has(needed), "the legend forgot %s" % needed)
	for needed: String in ["LS", "RS", "A", "Y", "START"]:
		check(pads.has(needed), "the pad legend forgot %s" % needed)
	check(not pads.has("?"), "a pad cap has no name: %s" % [pads])
	check(K.ENTRIES.size() >= 6, "the legend shrank to %d entries" % K.ENTRIES.size())


## A moved key shows on its cap; a moved walking key keeps the four together.
func test_the_caps_follow_the_keys() -> void:
	var binds := Keys.rebind({}, &"interact", KEY_F)
	check(K.cap(&"interact", binds, false) == "F", "interact on F shows %s" % K.cap(&"interact", binds, false))
	binds = Keys.rebind({}, &"move_forward", KEY_Z)
	check(K.cap(&"move", binds, false) == "ZASD", "walking on ZASD shows %s" % K.cap(&"move", binds, false))
