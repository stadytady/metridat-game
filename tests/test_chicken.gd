extends "res://tests/test_case.gd"
## Chickens stay home and run away from the player, never towards them.


func test_clamp_home() -> void:
	var home := Vector3(10, 5, -3)
	var p := Chicken.clamp_home(Vector3(20, 9, -3), home, 1.5)
	check(p.is_equal_approx(Vector3(11.5, 5, -3)), "clamped onto the circle at home height: %s" % p)
	var q := Chicken.clamp_home(Vector3(10.5, 7, -2.8), home, 1.5)
	check(q.is_equal_approx(Vector3(10.5, 5, -2.8)), "inside stays put: %s" % q)


func test_flee_moves_away_and_stays_home() -> void:
	var home := Vector3.ZERO
	var r := 1.6
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 200:
		var a := rng.randf_range(0, TAU)
		var p := Chicken.clamp_home(Vector3(cos(a), 0, sin(a)) * rng.randf_range(0, r), home, r)
		var b := rng.randf_range(0, TAU)
		var threat := p + Vector3(cos(b), 0, sin(b)) * rng.randf_range(0.3, Chicken.FLEE_DIST)
		var t := Chicken.flee_target(p, threat, home, r)
		check(Vector2(t.x, t.z).length() <= r + 1e-3, "target outside home: %s" % t)
		var d0 := Vector2(p.x - threat.x, p.z - threat.z).length()
		var d1 := Vector2(t.x - threat.x, t.z - threat.z).length()
		check(d1 >= d0 - 1e-3, "runs towards the threat: %.2f -> %.2f" % [d0, d1])
