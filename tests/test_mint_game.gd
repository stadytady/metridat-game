extends "res://tests/test_case.gd"
## Striking staters at Sosias's anvil: a blow on the mark is crisp, near it the
## design doubles, off it the blank slides; one blow a coin, three blanks; the
## needle sweeps the whole meter and the mark stays on it; the panel takes a
## key only once the E that opened it has come up, and says what each coin is.

const P := preload("res://scripts/ui/mint_panel.gd")


func test_the_blow_lands_where_the_needle_is() -> void:
	check(MintGame.grade(0.5, 0.5) == MintGame.TRUE, "dead on the mark is not true")
	check(MintGame.grade(0.5 + MintGame.MARK_HALF * 0.9, 0.5) == MintGame.TRUE, "inside the mark is not true")
	check(MintGame.grade(0.5 + MintGame.MARK_HALF * 1.5, 0.5) == MintGame.GLANCE, "just past the mark is not a glancing blow")
	check(MintGame.grade(0.5 + MintGame.MARK_HALF * (MintGame.NEAR + 0.2), 0.5) == MintGame.MISS, "far off the mark is not a miss")
	check(MintGame.quality(MintGame.TRUE) == "crisp" and MintGame.quality(MintGame.GLANCE) == "doubled"
			and MintGame.quality(MintGame.MISS) == "off_centre", "the coins are misnamed")
	check(MintGame.doubled(MintGame.GLANCE) and not MintGame.doubled(MintGame.TRUE), "the wrong blow doubles the design")
	check(MintGame.offset(MintGame.TRUE, 0) == Vector2.ZERO and MintGame.offset(MintGame.MISS, 0).length() > 0.15,
			"a true blow slides the design or a miss leaves it in the middle")


func test_the_needle_sweeps_and_the_mark_stays_on_the_meter() -> void:
	var lo := 1.0
	var hi := 0.0
	var t := 0.0
	var ontime := 0.0
	while t < 20.0:
		var n := MintGame.needle(t)
		lo = minf(lo, n)
		hi = maxf(hi, n)
		for b in MintGame.BLANKS:
			var m := MintGame.mark(t, b)
			check(m - MintGame.MARK_HALF >= 0.0 and m + MintGame.MARK_HALF <= 1.0, "the mark leaves the meter at %.2f s" % t)
		if MintGame.grade(n, MintGame.mark(t, 0)) == MintGame.TRUE:
			ontime += 1.0 / 60.0
		t += 1.0 / 60.0
	check(lo < 0.1 and hi > 0.9, "the needle sweeps only %.2f..%.2f" % [lo, hi])
	# hittable but not free: the needle is on the mark some of the time, not most
	check(ontime > 1.0 and ontime < 8.0, "the needle sits on the mark %.1f s of 20" % ontime)


func test_one_blow_a_coin_three_blanks() -> void:
	var g := MintGame.new()
	var made := 0
	while not g.over() and made < 10:
		g.clock += 0.37
		g.strike()
		made += 1
	check(made == MintGame.BLANKS and g.grades.size() == MintGame.BLANKS, "%d blows for %d blanks" % [made, MintGame.BLANKS])
	check(g.strike() == -1, "a fourth blow struck something")
	g.reset()
	check(g.grades.is_empty() and g.clock == 0.0, "new blanks keep the old coins")


func test_the_panel_strikes_once_e_comes_up() -> void:
	var p: CanvasLayer = P.new()
	Engine.get_main_loop().root.add_child(p)
	var kept := Game.ui_blocking
	p.open()
	var coins: Array[String] = []
	p.struck.connect(func(q: String) -> void: coins.append(q))
	# the E that opened it is still down: nothing strikes
	p._armed = false
	p.key(true, true)
	var early: int = p.game.grades.size()
	# up, then each press strikes the next blank; put the needle on the mark first
	for i in MintGame.BLANKS:
		p.key(false, false)
		var t := 0.0
		while MintGame.grade(MintGame.needle(t), MintGame.mark(t, i)) != MintGame.TRUE:
			t += 0.01
		p.game.clock = t
		p.key(true, true)
	var verdict: String = p._verdict.text
	var blocking: bool = Game.ui_blocking
	p.close()
	await Engine.get_main_loop().process_frame
	check(early == 0, "the held E struck as the panel opened")
	check(coins == ["crisp", "crisp", "crisp"], "three blows on the mark made %s" % [coins])
	check(verdict == tr("UI_MINT_DONE_CRISP"), "after a crisp coin Sosias says %s" % verdict)
	check(blocking, "the panel did not hold the input")
	check(not Game.ui_blocking, "the panel kept the input after closing")
	Game.ui_blocking = kept
