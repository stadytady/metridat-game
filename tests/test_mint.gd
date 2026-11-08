extends "res://tests/test_case.gd"
## The coin striker's room by the mule's pen: it stands on its own plot (not in
## the pen, not on the street, not in the houses up the street), the man sits
## inside it, his hammer lands on the punch and the punch on the die, the blows
## keep their beat, and at dusk he rests and the lamps are lit.

const M := preload("res://scripts/world/mint.gd")
const LIFE := preload("res://scripts/world/life.gd")


func test_the_room_stands_on_its_own_plot() -> void:
	var r := M.footprint()
	# the pen's fence, every post of it, stays outside the walls
	var fence: Dictionary = LIFE.yard_fence()
	for p: Vector2 in fence["posts"]:
		check(not r.grow(0.4).has_point(p), "a fence post of the pen at %s stands in the mint (%s)" % [p, r])
	# the street's paving stays clear, and so do the steps down to it
	for x in range(int(r.position.x), int(r.end.x) + 1):
		var edge := Topo.street_z(float(x)) + Topo.STREET_HALF
		check(r.position.y - 2.0 > edge, "the mint's steps run onto the street at x %d (front %.2f, paving to %.2f)" % [x, r.position.y, edge])
	# the town's own street ends east of it: none of its houses reach this far
	check(r.position.x > -4.6, "the mint reaches the courtyard up the street (%.2f)" % r.position.x)


func test_the_hammer_keeps_its_beat() -> void:
	# lands at the end of every cycle, at the top in between
	for k in 5:
		var at := (k + 1) * M.STRIKE_EVERY
		var low := minf(M.hammer_lift(at - 1.0 / 15.0), minf(M.hammer_lift(at), M.hammer_lift(at + 1.0 / 30.0)))
		check(low < 0.1, "the hammer is %.2f up when it should land" % low)
		check(M.hammer_lift(at - M.STRIKE_EVERY * (1.0 - M.RISE) - 0.02) > 0.9, "the hammer never reaches the top")
	check(M.blows(0.0, M.STRIKE_EVERY * 10.0 + 0.01) == 10, "ten cycles, %d blows" % M.blows(0.0, M.STRIKE_EVERY * 10.0 + 0.01))
	check(M.blows(0.2, 0.3) == 0, "a blow between two landings")


func test_he_strikes_the_punch_on_the_die() -> void:
	var m: Mint = M.new()
	Engine.get_main_loop().root.add_child(m)
	var room := M.footprint()
	var seat: Node3D = m.get_node("Striker")
	check(room.grow(-0.3).has_point(Vector2(seat.global_position.x, seat.global_position.z)), "the striker sits outside his room at %s" % seat.global_position)
	Figure.apply_pose(m._joints, "strike", M.swing(0.0))
	var landed := m.hammer_face().distance_to(m.punch_head())
	var tip := m.punch_tip()
	Figure.apply_pose(m._joints, "strike", M.swing(1.0))
	var raised := m.hammer_face().distance_to(m.punch_head())
	var raised_y := m.hammer_face().y - m.punch_head().y
	m.free()
	check(landed < 0.12, "the hammer lands %.2f m from the punch" % landed)
	check(raised > 0.3 and raised_y > 0.25, "at the top the hammer is only %.2f m from the punch (%.2f above)" % [raised, raised_y])
	check(tip.y > Topo.terrain(tip.x, tip.z) + 0.3, "the die sits at %.2f, on the floor" % tip.y)


func test_he_rests_at_dusk_and_the_lamps_are_lit() -> void:
	var m: Mint = M.new()
	var atm := Node.new()
	atm.set_script(preload("res://tests/fake_hour.gd"))
	atm.set("t", 0.2)
	m._atm = atm
	Engine.get_main_loop().root.add_child(m)
	m._atm = atm
	m._step(0.1)
	var day_work := m.working() and not m._door_lamp.lit
	var before := m.hits
	for k in 40:
		m._step(0.1)
	var struck := m.hits - before
	atm.set("t", DayCycle.LAMPS_ON)
	m._step(0.1)
	var lit := not m.working() and m._door_lamp.lit and m._shelf_light.visible
	var at_night := m.hits
	for k in 40:
		m._step(0.1)
	var quiet := m.hits == at_night
	m.free()
	atm.free()
	check(day_work, "by day he does not work, or the door lamp burns")
	check(struck >= 3 and struck <= 4, "in 4 s he struck %d blows" % struck)
	check(lit, "at dusk the lamps are dark or he still swings")
	check(quiet, "he strikes after dusk")
