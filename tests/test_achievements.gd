extends "res://tests/test_case.gd"
## Achievements: five ids that Steam will know by the same names, pure progress
## rules, and translations for every name and description.

const A := preload("res://scripts/core/achievements.gd")
const CSV := "res://data/i18n/strings.csv"


func test_five_well_formed_ids() -> void:
	check(A.LIST.size() == 8, "expected 8 achievements, got %d" % A.LIST.size())
	var steam := RegEx.create_from_string("^ACH_[A-Z0-9_]+$")
	for id: String in A.LIST:
		check(steam.search(id) != null, "%s is not a Steam-friendly API name" % id)
		var row: Array = A.LIST[id]
		check(row.size() == 3, "%s has %d fields, expected 3" % [id, row.size()])
		check(String(row[0]).begins_with("ACH_"), "%s name key is %s" % [id, row[0]])
		check(String(row[1]).begins_with("ACH_"), "%s description key is %s" % [id, row[1]])


func test_the_quiet_ones() -> void:
	check(A.silent_earned(0, true), "the silent run is not earned at the dream")
	check(not A.silent_earned(1, true), "silent after a single talk")
	check(not A.silent_earned(0, false), "silent before the dream")
	check(A.again_earned({"actor": 2}), "the second talk does not count")
	check(not A.again_earned({"actor": 1}), "the first talk already counts as again")
	check(not A.again_earned({}), "no talks at all counts as again")
	check(A.night_earned(A.NIGHT_SECONDS), "a full minute does not count")
	check(not A.night_earned(A.NIGHT_SECONDS - 1.0), "one second short already counts")


func test_progress_rules() -> void:
	var none := A.satisfied(0, 8, 0, 17, 0, 5, false)
	check(none.is_empty(), "something is earned at the start: %s" % [none])
	var first := A.satisfied(1, 8, 0, 17, 0, 5, false)
	check(first == PackedStringArray(["ACH_FIRST_FIND"]), "one find gave %s" % [first])
	var dream := A.satisfied(0, 8, 0, 17, 0, 5, true)
	check(dream == PackedStringArray(["ACH_DREAM"]), "the dream alone gave %s" % [dream])
	var lamps := A.satisfied(0, 8, 17, 17, 0, 5, false)
	check(lamps == PackedStringArray(["ACH_ALL_LAMPS"]), "all lamps gave %s" % [lamps])
	var heard := A.satisfied(0, 8, 0, 17, 5, 5, false)
	check(heard == PackedStringArray(["ACH_HEARD_ALL"]), "all voices gave %s" % [heard])
	var all := A.satisfied(8, 8, 17, 17, 5, 5, true)
	check(all.size() == 5, "a finished game gave %d of 5" % all.size())


func test_every_key_is_translated() -> void:
	var table := {}
	var f := FileAccess.open(CSV, FileAccess.READ)
	if f == null:
		check(false, "no " + CSV)
		return
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() >= 3 and row[0] != "":
			table[row[0]] = true
	check(table.has("UI_ACHIEVEMENT"), "no toast prefix")
	check(table.has("UI_ACHIEVEMENT_CAPTION"), "no popup caption")
	for id: String in A.LIST:
		var row: Array = A.LIST[id]
		check(table.has(String(row[0])), "%s missing from strings.csv" % row[0])
		check(table.has(String(row[1])), "%s missing from strings.csv" % row[1])


## The card's cup is drawn in code: tiny, cut out, and clearly a cup.
func test_popup_cup_is_drawn() -> void:
	var tex := AchievementPopup.icon_texture()
	check(tex != null, "no achievement icon")
	if tex == null:
		return
	var img: Image = tex.get_image()
	check(img.get_width() <= 128 and img.get_height() <= 128, "the icon is %s" % img.get_size())
	check(img.get_pixel(0, 0).a == 0.0, "the icon corner is opaque")
	var opaque := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				opaque += 1
	check(opaque > 40, "the cup is only %d pixels" % opaque)
