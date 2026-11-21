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


func _storm_seed() -> int:
	for s in range(1, 200):
		if W.kind(s) == W.STORM:
			return s
	return 0


## Of the wet walks about one in four is a storm; the dry third stays dry.
func test_some_wet_walks_are_storms() -> void:
	var storms := 0
	var showers := 0
	for s in range(1, 1201):
		match W.kind(s):
			W.STORM:
				storms += 1
				check(posmod(s, W.DRY_ONE_IN) != 0, "seed %d is a dry walk and a storm" % s)
			W.SHOWER:
				showers += 1
	var share := float(storms) / float(storms + showers)
	check(share > 0.18 and share < 0.32, "%.2f of the wet walks are storms, expected about a quarter" % share)
	check(W.kind(0) == W.DRY, "automation's walk is not dry")
	var s := _storm_seed()
	check(s > 0 and s < 120, "no storm among the seeds the shower test walks (%d)" % s)


## A storm: rains longer than a shower, all of it storm, gone before dusk;
## a shower carries no storm at all.
func test_a_storm_is_a_longer_darker_rain() -> void:
	var s := _storm_seed()
	var wet := 0
	var t := 0.0
	while t <= 1.0:
		var r := W.rain_at(t, s)
		check(is_equal_approx(W.storm_at(t, s), r), "the storm and its rain part at %.2f" % t)
		if r > 0.5:
			wet += 1
		t += 0.005
	check(wet * 0.005 > W.SHOWER_HALF * 1.4, "the storm is no longer than a shower")
	check(W.rain_at(DayCycle.LAMPS_ON - 0.05, s) == 0.0, "the storm runs into dusk")
	var sh := _rainy_seed()
	check(W.kind(sh) == W.SHOWER or W.kind(sh) == W.STORM, "the rainy seed is dry")
	for seed in range(1, 120):
		if W.kind(seed) == W.SHOWER:
			check(W.storm_at(0.3, seed) == 0.0, "a shower walk has a storm")
	var k := DayCycle.sample(0.3)
	var shower := W.apply(k, 1.0, 0.0)
	var storm := W.apply(k, 1.0, 1.0)
	check(float(storm.sun_energy) < float(shower.sun_energy) * 0.5, "the storm's sun is no dimmer than the shower's")
	check(float(storm.fog_end) < float(shower.fog_end), "the storm's haze is no closer")
	check((storm.fog_color as Color).get_luminance() < (shower.fog_color as Color).get_luminance() * 0.8, "the storm's sky is no darker")
	check(float(storm.ambient_energy) < float(shower.ambient_energy), "the storm's shade is no deeper")
	check(storm.sun_elevation == k.sun_elevation, "the storm moves the sun")


func test_the_storm_wind_drives_harder() -> void:
	var inland := Vector3(Sea.ONSHORE.x, 0, Sea.ONSHORE.y).normalized()
	for t: float in [0.0, 3.0, 11.5]:
		var calm := W.drift(t, 0.0)
		var hard := W.drift(t, 1.0)
		check(hard.normalized().dot(inland) > 0.99, "the storm blows out to sea at %.1f s" % t)
		check(hard.length() > calm.length() * 2.0, "the storm wind is no harder at %.1f s" % t)


## Lightning only in the heart of a storm, brief, now and then; and every bolt
## is heard once, a second or more after it is seen.
func test_lightning_and_its_thunder() -> void:
	var bolts := 0
	var lit := 0
	var steps := 0
	var t := 0.0
	var was := false
	while t < 600.0:
		check(W.flash(t, W.BOLT_FROM - 0.01) == 0.0, "lightning outside the storm's heart at %.2f s" % t)
		var f := W.flash(t, 1.0)
		check(f >= 0.0 and f <= 1.0, "a flash of %.2f" % f)
		if f > 0.0:
			lit += 1
			if not was:
				bolts += 1
		was = f > 0.0
		steps += 1
		t += 1.0 / 30.0
	var per_min := bolts / 10.0
	check(per_min >= 5.0 and per_min <= 9.0, "%.1f bolts a minute" % per_min)
	check(float(lit) / steps < 0.06, "the sky is lit %.0f%% of the time" % (100.0 * lit / steps))
	# thunder: heard in pieces of the clock, each bolt exactly once
	var heard := {}
	t = 0.0
	while t < 600.0:
		for n in W.thunders(t, t + 0.25):
			check(not heard.has(n), "bolt %d is heard twice" % n)
			heard[n] = true
			var b := W.bolt_time(n)
			check(b >= 0.0, "thunder from window %d that had no bolt" % n)
			var lag := t + 0.25 - b
			check(lag >= 1.0 - 0.001 and lag <= W.THUNDER_LAG + 0.26, "thunder %.2f s after its bolt" % lag)
		t += 0.25
	var seen := 0
	for n in range(1, int(560.0 / W.BOLT_EVERY)):
		if W.bolt_time(n) >= 0.0:
			seen += 1
			check(heard.has(n), "bolt %d is never heard" % n)
	check(seen > 0, "no bolts to hear")
	var k := DayCycle.sample(0.3)
	check(W.lit_by_bolt(k, 0.0) == k, "no bolt changes the light")
	check(float(W.lit_by_bolt(k, 1.0).ambient_energy) > float(k.ambient_energy) + 1.0, "a bolt does not light the town")


## The developer menu's weather over the walk's, and none of it in the dream.
func test_the_menu_forces_the_weather() -> void:
	var was := [Game.weather_seed, Game.weather_override, Game.dreaming]
	Game.weather_seed = 0
	Game.weather_override = -1
	check(W.now(0.3) == Vector2.ZERO, "a dry walk rains")
	Game.weather_override = W.STORM
	check(W.now(0.3) == Vector2(1, 1), "the menu's storm does not blow")
	check(W.now(0.9) == Vector2(1, 1), "the menu's storm waits for the afternoon")
	Game.weather_override = W.SHOWER
	check(W.now(0.3) == Vector2(1, 0), "the menu's shower is not a plain shower")
	Game.weather_seed = _storm_seed()
	Game.weather_override = W.DRY
	check(W.now(0.3) == Vector2.ZERO, "the menu cannot hold a storm off")
	Game.weather_override = -1
	var mid := 0.0
	var best := 0.0
	var t := 0.0
	while t <= 1.0:
		if W.rain_at(t, Game.weather_seed) > best:
			best = W.rain_at(t, Game.weather_seed)
			mid = t
		t += 0.005
	check(W.now(mid).y > 0.9, "the walk's own storm is lost when the menu lets go")
	Game.weather_override = W.STORM
	Game.dreaming = true
	check(W.now(0.3) == Vector2.ZERO, "it storms in the dream")
	Game.weather_seed = was[0]
	Game.weather_override = was[1]
	Game.dreaming = was[2]


## The swell: the sea's height and the shader rise together with Sea.swell.
func test_the_storm_raises_the_swell() -> void:
	var was := Sea.swell
	Sea.swell = 1.0
	var calm := Sea.height_at(95.0, 10.0, 3.0)
	Sea.swell = W.STORM_SWELL
	var rough := Sea.height_at(95.0, 10.0, 3.0)
	Sea.swell = was
	check(absf(calm) > 0.05, "the sample point has no wave")
	check(is_equal_approx(rough, calm * W.STORM_SWELL), "the storm swell is not the calm one scaled")


## The rain slants with the wind: a little in a shower, hard in a storm, and
## always with its foot inland, the way the wind blows.
func test_the_rain_slants_with_the_wind() -> void:
	var inland := Vector2(Sea.ONSHORE.x, Sea.ONSHORE.y).normalized()
	var t := 0.0
	while t < 30.0:
		var shower := W.fall_velocity(t, 0.0)
		var storm := W.fall_velocity(t, 1.0)
		check(is_equal_approx(storm.y, -W.FALL), "the wind changes how fast the rain falls")
		check(Vector2(storm.x, storm.z).normalized().dot(inland) > 0.99, "the rain slants out to sea at %.1f s" % t)
		var a := W.slant_deg(shower)
		var b := W.slant_deg(storm)
		check(a > 8.0 and a < 25.0, "a shower slants %.0f deg at %.1f s" % [a, t])
		check(b > a + 10.0, "the storm slants no more than the shower (%.0f vs %.0f deg)" % [b, a])
		check(b > 20.0 and b < 50.0, "a storm slants %.0f deg at %.1f s" % [b, t])
		t += 0.5
	check(is_equal_approx(W.slant_deg(Vector3.DOWN), 0.0), "straight rain reads as slanted")
	# the streak is drawn along y, the axis the particles align to their flight
	var m := W.streak_mesh(StandardMaterial3D.new())
	var box := m.get_aabb()
	check(box.size.y > box.size.x * 10.0 and box.size.y > box.size.z * 10.0, "the streak does not lie along y: %s" % box)
