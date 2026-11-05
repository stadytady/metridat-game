extends "res://tests/test_case.gd"
## The steppe west of town: mounds stand on the ground, the flock stays in its
## pasture, and a sheep grazes more than it looks up.

const S := preload("res://scripts/world/steppe.gd")
const SH := preload("res://scripts/npc/sheep.gd")


func test_mounds_stand_on_the_ground() -> void:
	var spots := S.kurgan_spots()
	check(spots.size() >= 5, "only %d mounds out there" % spots.size())
	for p: Vector3 in spots:
		check(p.x < -105.0, "a mound stands at x=%.1f, not west of the town" % p.x)
		check(is_equal_approx(p.y, Topo.terrain(p.x, p.z)), "a mound floats or sinks at %s" % p)


func test_pasture_sits_between_terrace_and_sea() -> void:
	var p := S.pasture()
	check(p.x < Topo.HILL_CENTER.x - 12.0, "the pasture at x=%.1f is too close to the terrace" % p.x)
	check(p.y > Topo.SEA_LEVEL + 1.0, "the pasture is in the water")
	check(p.y < Topo.HILL_PLATFORM_TOP, "the pasture is higher than the terrace")


func test_sheep_graze_more_than_they_look() -> void:
	var down := 0
	var samples := 140
	for i in samples:
		var a := SH.head_angle(i * SH.CYCLE / samples)
		check(a <= SH.LIFT + 0.01 and a >= SH.GRAZE - 0.01, "the head goes to %.0f deg" % a)
		if a < SH.GRAZE + 6.0:
			down += 1
	check(down >= samples * 0.7, "grazes only %d of %d moments" % [down, samples])


func test_ambles_stay_home() -> void:
	var home := Vector3(-140.0, 20.0, 16.0)
	for i in 60:
		var p := SH.next_stop(home, 5.0, i * 0.7)
		var away := Vector2(p.x - home.x, p.z - home.z).length()
		check(away <= 5.01, "a sheep walks %.2f m from home" % away)
