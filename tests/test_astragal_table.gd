extends "res://tests/test_case.gd"
## The knucklebones window: the bones fly from the hand, come down on the slab
## and lie showing the counts the rules dealt; no two lie on one another; the
## table does not throw by itself as it opens, and an empty cell is a dash.

const T := preload("res://scripts/ui/astragal_table.gd")
const PANEL := preload("res://scripts/ui/astragal_panel.gd")


func test_a_bone_shows_the_face_it_was_turned_to() -> void:
	for v in range(1, AstragalGame.FACES + 1):
		for yaw: float in [-0.6, 0.0, 0.4, 2.0]:
			check(T.face_up(T.face_basis(v, yaw)) == v, "a bone turned to %d shows %d (yaw %.1f)" % [v, T.face_up(T.face_basis(v, yaw)), yaw])


func test_the_bones_come_down_apart_on_their_own_half() -> void:
	for n in range(1, 8):
		for side in 2:
			var spots: Array[Vector3] = []
			for i in AstragalGame.BONES:
				var p := T.spot(side, i, n)
				check(absf(p.x) < T.SLAB.x / 2.0 - 0.1 and absf(p.z) < T.SLAB.z / 2.0 - 0.05, "bone %d lands off the slab at %s" % [i, p])
				check((p.z > 0.0) == (side == 0), "bone %d of side %d lands on the other half" % [i, side])
				for q: Vector3 in spots:
					check(p.distance_to(q) > T.BONE_LEN * T.BONE_SCALE + 0.02, "two bones land on one another at %s" % p)
				spots.append(p)


func test_a_bone_flies_up_comes_down_and_lies_still() -> void:
	var start: Vector3 = T.HANDS[0]
	var at := T.spot(0, 2, 1)
	var final := T.face_basis(3, 0.3)
	var rest := T.rest_height()
	var mid := T.pose(start, at, final, Vector3(1, 0.2, 0.5), 2.0, T.LAND_AT * 0.5, rest)
	check(mid.origin.y > maxf(start.y, rest) + 0.1, "the bone does not rise in flight (%.2f)" % mid.origin.y)
	check(T.face_up(mid.basis) != 3 or not mid.basis.is_equal_approx(final), "the bone does not tumble in flight")
	var end := T.pose(start, at, final, Vector3(1, 0.2, 0.5), 2.0, 1.0, rest)
	check(end.origin.distance_to(at + Vector3(0, rest, 0)) < 0.001, "the bone does not come to rest on its spot")
	check(end.basis.is_equal_approx(final), "the bone does not come to rest showing its face")


## The window itself: throw a hand, run the clock, read what the bones show.
func test_the_window_shows_what_the_rules_dealt() -> void:
	var table: AstragalTable = T.new()
	Engine.get_main_loop().root.add_child(table)
	var mine: Array[int] = [1, 2, 3, 4, 2]
	var theirs: Array[int] = [4, 4, 1, 3, 2]
	var landed: Array[int] = []
	var settled := [false]
	table.landed.connect(func(side: int) -> void: landed.append(side))
	table.settled.connect(func() -> void: settled[0] = true)
	table.throw_hands(mine, theirs, 1)
	check(table.busy(), "nothing is in the air after the throw")
	for k in 120:
		table._process(1.0 / 30.0)
	check(settled[0] and not table.busy(), "the bones never came to rest")
	check(landed == [0, 1], "the hands landed as %s, not the player's then the children's" % [landed])
	check(table.shown(0) == mine, "the player's bones show %s, the rules dealt %s" % [table.shown(0), mine])
	check(table.shown(1) == theirs, "the children's bones show %s, the rules dealt %s" % [table.shown(1), theirs])
	table.free()


func test_the_table_waits_for_the_key_that_opened_it() -> void:
	var p: CanvasLayer = PANEL.new()
	Engine.get_main_loop().root.add_child(p)
	p.open()
	p._armed = false  # as open() leaves it when E is still down
	# the frame the table opened, E still down and "just pressed"
	p._key(true, true)
	p._key(true, false)
	var auto: int = p._game.throws.size()
	check(not p._bones_mine.text.contains("Ð") and not p._bones_mine.text.contains("вЂ"), "an empty cell reads %s" % p._bones_mine.text)
	check(p._bones_mine.text == "\u2014", "an empty cell is not a dash but %s" % p._bones_mine.text)
	# let go, press again
	p._key(false, false)
	p._key(true, true)
	var thrown: int = p._game.throws.size()
	var counted_early: int = p._log.get_child_count()
	# a press while the bones fly does nothing
	p._key(false, false)
	p._key(true, true)
	var while_flying: int = p._game.throws.size()
	for k in 120:
		p._table._process(1.0 / 30.0)
	var counted: int = p._log.get_child_count()
	var sum_ok: bool = thrown == 1 and p._sum_mine.text == str(p._game.throws[0].sum_mine)
	p.free()
	Game.ui_blocking = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	check(auto == 0, "the table threw by itself as it opened")
	check(thrown == 1, "a fresh E threw %d times" % thrown)
	check(counted_early == 0, "the throw is counted before its bones land")
	check(while_flying == 1, "a press while the bones fly threw again")
	check(counted == 1, "the throw is not counted once the bones lie still")
	check(sum_ok, "the sum does not show the throw")
