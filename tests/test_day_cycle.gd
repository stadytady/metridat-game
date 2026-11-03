extends "res://tests/test_case.gd"
## The hour drives every light; check its ends and its continuity.


func test_ends_match_keys() -> void:
	var day := DayCycle.sample(0.0)
	var night := DayCycle.sample(1.0)
	check(day.sun_energy > 1.0 and day.moon_energy == 0.0, "afternoon: sun up, no moon")
	check(night.sun_energy == 0.0 and night.moon_energy > 0.2, "night: no sun, moon up")
	check(day.sky_weights == Vector3(1, 0, 0) and night.sky_weights == Vector3(0, 0, 1), "sky weights at the ends")
	check(night.ambient_energy < day.ambient_energy, "night is darker")


func test_continuous_and_monotonic_darkening() -> void:
	var prev: Dictionary = DayCycle.sample(0.0)
	for i in range(1, 101):
		var cur := DayCycle.sample(i / 100.0)
		check(absf(cur.sun_energy - prev.sun_energy) < 0.15, "sun energy jumps at t=%.2f" % (i / 100.0))
		check(cur.ambient_energy <= prev.ambient_energy + 1e-6, "ambient brightens at t=%.2f" % (i / 100.0))
		check(cur.sun_elevation <= prev.sun_elevation + 1e-6, "sun rises at t=%.2f" % (i / 100.0))
		var w: Vector3 = cur.sky_weights
		check(absf(w.x + w.y + w.z - 1.0) < 1e-4, "sky weights do not sum to 1 at t=%.2f" % (i / 100.0))
		prev = cur


func test_target_follows_finds() -> void:
	check(DayCycle.target_for(0, 6) == 0.0, "start in the afternoon")
	check(DayCycle.target_for(6, 6) == 1.0, "all finds bring the night")
	check(DayCycle.target_for(3, 6) > DayCycle.target_for(2, 6), "each find moves the evening on")
