extends "res://tests/test_case.gd"
## The evening play: on from dusk, off in the dream and the prologue; the chorus
## keeps to the orchestra and never runs into itself; the watchers sit on the
## tiers, clear of Fedr's seat and of each other.

const P := preload("res://scripts/world/theatre_play.gd")
const T := preload("res://scripts/world/theatre.gd")


func test_play_runs_from_dusk() -> void:
	check(not P.on_at(DayCycle.LAMPS_ON - 0.01), "the play starts before dusk")
	check(P.on_at(DayCycle.LAMPS_ON), "no play at dusk")
	check(P.on_at(0.95), "no play late in the night")
	check(not P.on_at(0.95, true), "the play goes on in the dream")
	check(not P.on_at(DayCycle.PROLOGUE, false, true), "the play is on the evening of the prologue")


func test_chorus_keeps_to_the_orchestra() -> void:
	var t := 0.0
	while t < 2.0 * (P.STROPHE_WALK + P.STROPHE_HOLD):
		var pts: Array[Vector2] = []
		for i in P.CHORUS:
			var p := P.chorus_at(i, t)
			var r := p.distance_to(T.CENTER)
			check(r <= T.ORCHESTRA_R, "dancer %d at %.1f s is off the orchestra (r %.2f)" % [i, t, r])
			for q in pts:
				check(p.distance_to(q) > 0.55, "two dancers collide at %.1f s" % t)
			pts.append(p)
		t += 0.25


func test_strophe_comes_back() -> void:
	# the antistrophe ends where the strophe began, so the loop has no jump
	var cycle := 2.0 * (P.STROPHE_WALK + P.STROPHE_HOLD)
	for i in P.CHORUS:
		check(P.chorus_at(i, 0.0).distance_to(P.chorus_at(i, cycle - 0.001)) < 0.05, "dancer %d jumps at the loop" % i)


func test_watchers_sit_on_the_tiers() -> void:
	# the pelvis sits on the tier the feet are below: the "sit" seat height is one rise
	check(absf(Figure.SEAT["sit"] - T.TIER_RISE) < 0.06, "watchers float or sink: sit %.2f vs rise %.2f" % [Figure.SEAT["sit"], T.TIER_RISE])
	var seats: Array[Vector2] = []
	for s: Array in P.AUDIENCE:
		var tier: int = s[0]
		var a: float = s[1]
		check(tier >= 0 and tier < T.TIERS, "watcher on tier %d" % tier)
		check(a > T.ARC_FROM + 5.0 and a < T.ARC_TO - 5.0, "watcher at %.0f deg sits by a torch" % a)
		var p := P.seat_at(tier, a)
		check(p.distance_to(T.ACTOR_SEAT) > 0.9, "watcher at %.0f deg sits in Fedr's seat" % a)
		for q in seats:
			check(p.distance_to(q) > 0.6, "two watchers on one seat at %.0f deg" % a)
		seats.append(p)


func test_watchers_face_the_orchestra() -> void:
	for s: Array in P.AUDIENCE:
		var p := P.seat_at(s[0], s[1])
		var yaw := P.face_centre(p)
		var facing := Vector2(-sin(yaw), -cos(yaw))
		check(facing.dot((T.CENTER - p).normalized()) > 0.99, "a watcher looks away from the stage")
