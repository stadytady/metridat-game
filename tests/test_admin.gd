extends "res://tests/test_case.gd"
## The developer menu: the clock runs in one direction and stays inside the day,
## every viewpoint the screenshots use can be jumped to, and the story leaps (sleep,
## dream, waking) are named and unique.

const A := preload("res://scripts/ui/admin_panel.gd")
const WORLD := preload("res://scripts/world/world.gd")
const CSV := "res://data/i18n/strings.csv"


func _table() -> Dictionary:
	var table := {}
	var f := FileAccess.open(CSV, FileAccess.READ)
	if f == null:
		check(false, "no " + CSV)
		return table
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() >= 3 and row[0] != "":
			table[row[0]] = true
	return table


func test_the_clock_steps_go_forward_and_stay_in_the_day() -> void:
	check(A.TIME_STEPS.size() == A.TIME_KEYS.size(), "the clock and its labels disagree")
	check(is_equal_approx(A.TIME_STEPS[0], -1.0), "the first step does not give the hour back")
	for i in range(1, A.TIME_STEPS.size()):
		check(A.TIME_STEPS[i] > A.TIME_STEPS[i - 1], "the clock goes backwards at %d" % i)
		check(A.TIME_STEPS[i] <= 1.25, "a step is past the dream hour: %.2f" % A.TIME_STEPS[i])


func test_every_place_has_a_name_and_a_row() -> void:
	var table := _table()
	var places: PackedStringArray = WORLD.viewpoints().keys()
	check(places.size() >= 8, "only %d viewpoints to jump to" % places.size())
	for place: String in places:
		check(place != "", "a viewpoint has no name")
		var key: String = A.PLACE_KEYS.get(place, "")
		if key != "":
			check(table.has(key), "%s points at a missing key %s" % [place, key])
	for key: String in A.PLACE_KEYS.values():
		check(table.has(key), "the map points at a missing key %s" % key)


func test_labels_exist_for_every_clock_step() -> void:
	for i in A.TIME_KEYS.size():
		check(A.TIME_KEYS[i].begins_with("UI_ADMIN_"), "%s is not an admin key" % A.TIME_KEYS[i])


## The scene page: the dream is entered and left through the same calls the player
## uses, so the menu can never be the only thing that can sleep.
func test_the_story_leaps_are_named_and_unique() -> void:
	var table := _table()
	var ids := {}
	for a: Array in A.ACTIONS:
		check(a.size() == 2, "an action has %d fields" % a.size())
		var id := String(a[0])
		check(not ids.has(id), "duplicate action " + id)
		ids[id] = true
		check(table.has(String(a[1])), "%s is missing from strings.csv" % a[1])
	for needed: String in ["sleep", "dream", "wake", "lamps"]:
		check(ids.has(needed), "the menu cannot %s" % needed)
