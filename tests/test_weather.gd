extends "res://tests/test_case.gd"
## The walk's shower: a dry walk for seed 0 and for one seed in three, a single
## afternoon shower otherwise, gone by dusk; under it the hour stays the hour,
## only greyer; the rain leans inland with the wind; the seed survives a save.

const W := preload("res://scripts/world/weather.gd")


func _rainy_seed() -> int:
	for s in range(1, 50):
		if W.rain_at(0.0, s) == 0.0 and _peak(s) > 0.99:
			return s
	return 0


func _peak(seed: int) -> float:
	var best := 0.0
	var t := 0.0
	while t <= 1.0:
		best = maxf(best, W.rain_at(t, seed))
		t += 0.005
	return best


func test_dry_walks() -> void:
	check(_peak(0) == 0.0, "seed 0 (automation) rains")
	var dry := 0
	for s in range(1, 301):
		if _peak(s) == 0.0:
			dry += 1
	check(dry >= 90 and dry <= 110, "%d of 300 walks are dry, expected about a third" % dry)


func test_one_shower_in_the_afternoon() -> void:
	var s := _rainy_seed()
	check(s > 0, "no seed brings a shower")
	for seed in range(1, 120):
		if _peak(seed) == 0.0:
			continue
		check(W.rain_at(0.0, seed) == 0.0, "seed %d: the walk starts in rain" % seed)
		check(W.rain_at(DayCycle.LAMPS_ON, seed) == 0.0, "seed %d: still raining at dusk" % seed)
		# one shower: it rises once and falls once
		var turns := 0
		var prev := 0.0
		var up := true
		var t := 0.0
		while t <= 1.0:
			var r := W.rain_at(t, seed)
			if up and r < prev - 1e-6:
				up = false
				turns += 1
			elif not up and r > prev + 1e-6:
				up = true
				turns += 1
			prev = r
			t += 0.005
		check(turns == 1, "seed %d: %d turns, not one shower" % [seed, turns])


func test_under_cloud_the_hour_stays() -> void:
	for t: float in [0.1, 0.3, 0.45]:
		var k := DayCycle.sample(t)
		check(W.apply(k, 0.0) == k, "a dry hour is changed at %.2f" % t)
		var wet := W.apply(k, 1.0)
		check(wet.sun_elevation == k.sun_elevation, "the rain moves the sun")
		check(wet.sky_weights == k.sky_weights, "the rain changes the time of the sky")
		check(float(wet.sun_energy) < float(k.sun_energy) * 0.5, "the sun is not dimmed by the shower")
		check(float(wet.fog_end) < float(k.fog_end) * 0.5, "the haze does not close in")
		var g: Color = wet.fog_color
		var c: Color = k.fog_color
		check(absf(g.r - g.b) < absf(c.r - c.b), "the fog is no greyer in the rain")


func test_rain_leans_inland() -> void:
	var inland := Vector3(Sea.ONSHORE.x, 0, Sea.ONSHORE.y).normalized()
	var t := 0.0
	while t < 30.0:
		var d := W.drift(t)
		check(d.normalized().dot(inland) > 0.99, "the rain leans against the wind at %.1f s" % t)
		check(d.length() >= W.LEAN - 0.001 and d.length() <= W.LEAN + W.GUST + 0.001, "gust out of range at %.1f s" % t)
		t += 0.5


func test_seed_survives_a_save() -> void:
	var was := Game.weather_seed
	Game.weather_seed = 4242
	var data := SaveGame.snapshot(Vector3.ZERO, 0.0)
	Game.weather_seed = 0
	SaveGame.apply(data)
	check(Game.weather_seed == 4242, "the weather seed did not come back from the save")
	SaveGame.apply({"version": SaveGame.VERSION})
	check(Game.weather_seed == 0, "an old save without weather is not dry")
	Game.weather_seed = was
