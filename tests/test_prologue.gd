extends "res://tests/test_case.gd"
## The prologue: the arrival point is on the pier's planks, clear of the
## skipper and the cargo; its hour is dusk, between the last find's evening
## and the night; the talk's keys exist in both languages.


func test_arrival_on_the_pier_by_the_skipper() -> void:
	var p := Prologue.arrival_point()
	check(Topo.on_pier(p.x, p.z, 0.0), "the dreamer does not land on the pier: %s" % p)
	check(is_equal_approx(p.y, Topo.PIER_H), "not on the deck: y %.2f" % p.y)
	var s: Vector3 = load("res://scripts/world/harbour.gd").skipper_pos()
	var d := Vector2(p.x - s.x, p.z - s.z).length()
	check(d > 1.2 and d < 4.0, "too far from or too close to Damon: %.1f m" % d)
	# on the land side of him, so he is seen against the ship and the sea
	check(p.x < s.x, "the dreamer stands seaward of Damon")


func test_prologue_hour_is_dusk() -> void:
	check(DayCycle.PROLOGUE > 0.7 and DayCycle.PROLOGUE < 0.95, "the prologue is not at dusk: %.2f" % DayCycle.PROLOGUE)
	var dusk := DayCycle.sample(DayCycle.PROLOGUE)
	var day := DayCycle.sample(0.0)
	check(dusk.sun_energy < day.sun_energy, "dusk is as bright as the day")


func test_prologue_hour_comes_from_the_game() -> void:
	var was := Game.prologue
	Game.prologue = true
	check(is_equal_approx(Game.time_target(), DayCycle.PROLOGUE), "Game.time_target ignores the prologue")
	Game.prologue = false
	check(not is_equal_approx(Game.time_target(), DayCycle.PROLOGUE), "the prologue's hour stays after it")
	Game.prologue = was


func test_prologue_lines_are_translated() -> void:
	var text := FileAccess.get_file_as_string("res://data/dialogues/prologue.dialogue")
	var keys := PackedStringArray()
	for line in text.split("\n"):
		var t := line.strip_edges()
		if t.begins_with("Damon: "):
			keys.append(t.substr(7))
		elif t.begins_with("- "):
			keys.append(t.substr(2))
	check(keys.size() >= 8, "the prologue is too short: %d keys" % keys.size())
	for k in keys:
		for lang in ["en", "ru"]:
			TranslationServer.set_locale(lang)
			check(tr(k) != k, "%s has no %s text" % [k, lang])
	TranslationServer.set_locale("en")


## The voyage in: she starts far out on the strait and ends off the pier,
## closing all the way, and never sails through a ship riding at anchor.
func test_the_voyage_comes_in_from_far_out() -> void:
	var moored: Vector3 = load("res://scripts/world/harbour.gd").ship_pos()
	var start := Prologue.course_at(0.0)
	var end := Prologue.course_at(1.0)
	check(start.distance_to(moored) > 150.0, "she starts only %.0f m out" % start.distance_to(moored))
	check(end.distance_to(moored) < 45.0, "she ends %.0f m off the pier" % end.distance_to(moored))
	var last := INF
	for i in 41:
		var d := Prologue.course_at(i / 40.0).distance_to(moored)
		check(d < last + 0.01, "she turns away from the pier at %d/40" % i)
		last = d
	# heading follows the course: the bow points where she goes next
	for i in 10:
		var k := i / 10.0
		var yaw := Prologue.heading_at(k)
		var fwd := Vector3(cos(yaw), 0, -sin(yaw))
		var step := Prologue.course_at(k + 0.05) - Prologue.course_at(k)
		check(fwd.dot(step.normalized()) > 0.95, "she sails sideways at %.1f" % k)


func test_the_voyage_keeps_clear_of_the_anchored_ships() -> void:
	var ships: Script = load("res://scripts/world/ships.gd")
	for s: Array in ships.SHIPS:
		var at: Vector3 = ships.position_at(s[0], s[3], DayCycle.PROLOGUE)
		var clear := INF
		for i in 101:
			clear = minf(clear, Prologue.course_at(i / 100.0).distance_to(at))
		# two hulls of 16 m and some water between
		check(clear > 18.0 * float(s[2]), "she passes %.1f m from the ship at %s" % [clear, at])


## The legend runs in order inside the voyage, lines do not overlap, each is
## up long enough to read, and each is translated.
func test_the_legend_fits_the_voyage() -> void:
	var prev := 0.0
	for l: Array in Prologue.LEGEND:
		var a: float = l[1]
		var b: float = l[2]
		check(a >= prev, "%s starts before the last line ends" % l[0])
		check(b - a >= 4.5, "%s is up only %.1f s" % [l[0], b - a])
		check(b <= Prologue.VOYAGE, "%s runs past the voyage" % l[0])
		check(Prologue.legend_at((a + b) / 2.0) == l[0], "%s is not up in its own time" % l[0])
		prev = b
		for lang in ["en", "ru"]:
			TranslationServer.set_locale(lang)
			check(tr(l[0]) != l[0], "%s has no %s text" % [l[0], lang])
	TranslationServer.set_locale("en")
	check(Prologue.legend_at(Prologue.VOYAGE + 1.0).is_empty(), "the legend outlives the voyage")


## The anchor stock (a find) lies on the pier's planks, by the north edge,
## out of the way along the pier to the skipper.
func test_the_anchor_stock_lies_on_the_planks() -> void:
	var a: Vector2 = load("res://scripts/world/harbour.gd").ANCHOR_FIND
	for dx: float in [-0.55, 0.55]:
		check(Topo.on_pier(a.x + dx, a.y, 0.0), "the stock hangs off the pier at x %.2f" % (a.x + dx))
	check(a.y < Topo.PIER_Z - 0.6, "the stock lies in the middle of the way at z %.2f" % a.y)
	check(a.x < Topo.pier_x1() - 9.0, "the stock lies among the crew by the gangway")
