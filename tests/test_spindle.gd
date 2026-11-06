extends "res://tests/test_case.gd"
## The cottage woman spins: she looks like a woman, the spindle's thread stays
## within its lengths and grows while it turns, and the spindle hangs plumb under
## her right hand, in front of her skirt and above the floor.


func test_the_spinner_is_a_woman() -> void:
	var l := Figure.look_for("cottage_woman")
	check(Figure.face_of(l) == "face_woman", "the cottage woman has a man's face")
	check(not l.get("kerchief", "").is_empty(), "she goes bareheaded: the look gives her no kerchief")
	check(l.get("skirt", "") == "long", "her chiton does not reach the ground")


func test_the_thread_stays_within_its_lengths() -> void:
	var t := 0.0
	while t < Spindle.CYCLE * 2.0:
		var d := Spindle.drop(t)
		check(d >= Spindle.TOP - 1e-4 and d <= Spindle.BOTTOM + 1e-4, "thread %.2f m at %.2f s" % [d, t])
		t += 0.05


func test_it_sinks_while_turning_and_rises_while_wound() -> void:
	var early := Spindle.drop(0.5)
	var late := Spindle.drop(Spindle.DRAW - 0.2)
	check(late > early + 0.2, "the spindle does not sink: %.2f -> %.2f" % [early, late])
	var winding := Spindle.drop(Spindle.CYCLE - 0.2)
	check(winding < late - 0.2, "the yarn is not wound up: %.2f" % winding)
	check(not is_equal_approx(Spindle.turn(1.0), Spindle.turn(1.2)), "the spindle does not turn while it hangs")
	check(is_equal_approx(Spindle.turn(Spindle.DRAW + 0.3), Spindle.turn(Spindle.DRAW + 1.0)), "the spindle turns while she winds")


func test_it_hangs_in_front_of_her_and_above_the_floor() -> void:
	var root := Node3D.new()
	Engine.get_main_loop().root.add_child(root)
	var joints := Figure.build(root, "chiton_dark", Figure.look_for("cottage_woman"))
	Spindle.hold_distaff(joints)
	var hand := Spindle.right_hand(joints)
	var t := 0.0
	while t < Spindle.CYCLE:
		Figure.apply_pose(joints, "spin", Figure.motion("spin", t))
		var p := hand.global_position
		var foot := p.y - Spindle.drop(t) - 0.22  # the whorl's underside
		check(foot > 0.1, "the spindle drags on the floor: %.2f at %.1f s" % [foot, t])
		check(p.z < -0.3, "the thread runs through her skirt: hand at z %.2f" % p.z)
		check(p.y < 1.3, "the hand is up by her face: %.2f" % p.y)
		t += 0.4
	# the distaff stands up, its wool above the hand that holds it
	var grip: Node3D = (joints["l_elbow"] as Node3D).get_node("Distaff")
	var up := grip.global_transform.basis.y
	check(up.y > 0.85, "the distaff lies down: %s" % up)
	root.queue_free()
